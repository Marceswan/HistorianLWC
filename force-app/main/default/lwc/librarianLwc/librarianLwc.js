import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import startEnsure from '@salesforce/apex/HistorianAdminController.startEnsureHistorianObject';
import listConfigs from '@salesforce/apex/HistorianConfigAdminService.listConfigsByObject';
import upsertRoot from '@salesforce/apex/HistorianConfigAdminService.upsertRoot';
import deleteRoot from '@salesforce/apex/HistorianConfigAdminService.deleteRoot';
import listFields from '@salesforce/apex/HistorianConfigAdminService.listFields';
import upsertField from '@salesforce/apex/HistorianConfigAdminService.upsertField';
import deleteField from '@salesforce/apex/HistorianConfigAdminService.deleteField';
import listRecent from '@salesforce/apex/HistorianConfigAdminService.listRecentDeployResults';
import mdapiRemoteSiteOk from '@salesforce/apex/HistorianSetupService.mdapiRemoteSiteOk';
import isHistorianProvisioned from '@salesforce/apex/HistorianAdminController.isHistorianProvisioned';

export default class LibrarianLwc extends LightningElement {
    @track objectApi = '';
    @track configName = '';
    @track jobId;
    @track loading = false;
    @track configs = [];
    @track columns = [
        { label: 'Config Name', fieldName: 'configName' },
        { label: 'Object', fieldName: 'objectApi' },
        { label: 'Mode', fieldName: 'mode' },
        { label: 'Fields', fieldName: 'fields' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'Edit', name: 'edit' },
            { label: 'Manage Fields', name: 'fields' },
            { label: 'Delete', name: 'delete' }
        ]}}
    ];

    @track recent = [];
    @track recentColumns = [
        { label: 'When', fieldName: 'when', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { label: 'Status', fieldName: 'status', cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'State', fieldName: 'state' },
        { label: 'Errors', fieldName: 'errorCount' },
        { label: 'Component', fieldName: 'componentFullName' },
        { label: 'Type', fieldName: 'componentType' },
        { label: 'Problem', fieldName: 'problem' }
    ];

    @wire(listConfigs, { objectApi: '$objectApi' })
    wiredConfigs({ data, error }) {
        if (data) {
            console.log('Data from wire service:', JSON.stringify(data));
            this.configs = data.map(c => ({
                id: `${c.objectApiName}:${c.configName}`,
                configName: c.configName,
                objectApi: c.objectApiName,
                mode: c.trackMode === 'AllFields' ? 'All Fields' : 'Per Field',
                fields: '—',
                _raw: c
            }));
            console.log('Configs after mapping:', JSON.stringify(this.configs));
        }
        // eslint-disable-next-line no-console
        if (error) console.error(error);
    }

    handleObjectChange(event) {
        this.objectApi = event.target.value;
        this.refresh();
    }
    handleConfigChange(event) {
        this.configName = event.target.value;
    }
    async ensureHistorian() {
        try {
            this.loading = true;
            this.jobId = await startEnsure({ objectApi: this.objectApi, configName: this.configName });
            this.toast('Historian Job Enqueued', `Job Id: ${this.jobId}`, 'success');
            await this.loadRecent();
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }

    refresh() {
        // Trigger wire to refresh by poking objectApi reactive param
        const v = this.objectApi; this.objectApi = ''; this.objectApi = v;
    }

    openRemoteSite() {
        // Open the mdapi helper VF to configure Remote Site Setting
        // eslint-disable-next-line no-restricted-globals
        window.open('/apex/remotesitepage', '_blank');
    }

    // Row actions
    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') this.openRootModal(row._raw);
        if (action === 'delete') this.removeRoot(row._raw);
        if (action === 'fields') this.openFieldsModal(row._raw);
    }

    // Root modal state
    @track showRoot = false;
    @track rootForm = { developerName: '', label: '', configName: '', objectApiName: '', trackingStyle: 'Timeline', trackMode: 'AllFields', active: true, historyObjectApi: '' };
    modeOptions = [
        { label: 'All Fields', value: 'AllFields' },
        { label: 'Per Field', value: 'PerField' }
    ];
    styleOptions = [
        { label: 'Timeline', value: 'Timeline' },
        { label: 'Datatable', value: 'Datatable' },
        { label: 'Compact Cards', value: 'CompactCards' }
    ];

    newRoot() {
        this.rootForm = { 
            developerName: '', 
            label: 'Historian Config', // Provide default label
            configName: '', 
            objectApiName: this.objectApi || '', 
            trackingStyle: 'Timeline', 
            trackMode: 'AllFields', 
            active: true, 
            historyObjectApi: '' 
        };
        this.showRoot = true;
    }
    connectedCallback() {
        // Probe mdapi remote site readiness
        mdapiRemoteSiteOk().then(ok => {
            this.mdapiReady = ok;
        }).catch(() => { this.mdapiReady = false; });
        this.loadRecent();
    }
    openRootModal(raw) {
        // Debug to see what raw data we're getting
        console.log('Raw data received in openRootModal:', JSON.stringify(raw));
        
        // When editing, ensure all fields are properly mapped
        // Create a completely new object to trigger reactivity
        const newForm = {
            developerName: raw.developerName || '',
            label: raw.label || '',
            configName: raw.configName || '',
            objectApiName: raw.objectApiName || '',
            trackingStyle: raw.trackingStyle || 'Timeline',
            trackMode: raw.trackMode || 'AllFields',
            active: raw.active !== undefined ? raw.active : true,
            historyObjectApi: raw.historyObjectApi || ''
        };
        
        // Force reactivity by reassigning the entire tracked object
        this.rootForm = { ...newForm };
        
        console.log('rootForm after mapping:', JSON.stringify(this.rootForm));
        
        // Add a small delay to ensure DOM updates
        setTimeout(() => {
            this.showRoot = true;
        }, 0);
    }
    closeRoot() { this.showRoot = false; }
    async saveRoot() {
        try {
            this.loading = true;
            
            // Clear any existing field-level validation errors
            [...this.template.querySelectorAll('lightning-input')]
                .forEach(inputCmp => inputCmp.setCustomValidity(''));
            
            // Additional validation for trimmed values
            if (!this.rootForm.configName || this.rootForm.configName.trim() === '') {
                this.toast('Error', 'Config Name is required', 'error');
                return;
            }
            if (!this.rootForm.objectApiName || this.rootForm.objectApiName.trim() === '') {
                this.toast('Error', 'Object API Name is required', 'error');
                return;
            }
            
            // Log rootForm to see current values
            console.log('Current rootForm:', JSON.stringify(this.rootForm));
            
            // Create a clean object matching the Apex DTO structure
            const rootConfig = {
                developerName: this.rootForm.developerName || '',
                label: this.rootForm.label || this.rootForm.configName || 'Default Config',
                configName: this.rootForm.configName.trim(),
                objectApiName: this.rootForm.objectApiName.trim(),
                trackingStyle: this.rootForm.trackingStyle || 'Timeline',
                trackMode: this.rootForm.trackMode || 'AllFields',
                active: this.rootForm.active !== undefined ? this.rootForm.active : true,
                historyObjectApi: this.rootForm.historyObjectApi || '',
                requestId: null
            };
            
            console.log('RootConfig object created:', JSON.stringify(rootConfig));
            console.log('Calling Apex upsertRoot with rootConfig as input parameter');
            
            // Call Apex method with explicit parameter name
            const result = await upsertRoot({ input: rootConfig });
            console.log('Apex response:', result);
            this.toast('Saved', 'Configuration save enqueued', 'success');
            this.showRoot = false;
            await this.pollConfigs(8, 800);
            await this.loadRecent();
        } catch (e) {
            console.error('Error in saveRoot:', e);
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }
    async removeRoot(raw) {
        try {
            this.loading = true;
            await deleteRoot({ developerName: raw.developerName });
            this.toast('Deleted', 'Configuration deactivated', 'success');
            this.refresh();
            await this.loadRecent();
        } catch (e) {
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }

    // Fields modal state
    @track showFields = false;
    @track fieldsParent;
    @track fieldRows = [];
    @track fieldForm = { developerName: '', label: '', parentDeveloperName: '', fieldApiName: '', include: true };

    async openFieldsModal(raw) {
        this.fieldsParent = raw.developerName;
        await this.loadFields();
        this.showFields = true;
    }
    closeFields() { this.showFields = false; }
    async loadFields() {
        try {
            this.loading = true;
            const list = await listFields({ parentDeveloperName: this.fieldsParent });
            this.fieldRows = list;
        } catch (e) {
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }
    newField() {
        this.fieldForm = { developerName: '', label: '', parentDeveloperName: this.fieldsParent, fieldApiName: '', include: true };
    }
    async saveField() {
        try {
            this.loading = true;
            await upsertField({ input: this.fieldForm });
            this.toast('Saved', 'Field configuration save enqueued', 'success');
            this.fieldForm = { developerName: '', label: '', parentDeveloperName: this.fieldsParent, fieldApiName: '', include: true };
            // small delay to allow metadata to apply
            await this.sleep(800);
            await this.loadFields();
            await this.loadRecent();
        } catch (e) {
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }
    async deleteFieldRow(event) {
        const devName = event.target.dataset.devname;
        try {
            this.loading = true;
            await deleteField({ developerName: devName });
            this.toast('Deleted', 'Field configuration deactivated', 'success');
            await this.loadFields();
            await this.loadRecent();
        } catch (e) {
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }

    // Root handlers
    handleRootInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        console.log(`Field ${field} changed to: ${value}`);
        // Create a completely new object to ensure reactivity
        const updatedForm = Object.assign({}, this.rootForm);
        updatedForm[field] = value;
        this.rootForm = updatedForm;
        console.log('Updated rootForm:', JSON.stringify(this.rootForm));
    }
    handleRootModeChange(event) {
        const updatedForm = Object.assign({}, this.rootForm);
        updatedForm.trackMode = event.detail.value;
        this.rootForm = updatedForm;
    }
    handleRootStyleChange(event) {
        const updatedForm = Object.assign({}, this.rootForm);
        updatedForm.trackingStyle = event.detail.value;
        this.rootForm = updatedForm;
    }
    handleRootActiveChange(event) {
        const updatedForm = Object.assign({}, this.rootForm);
        updatedForm.active = event.target.checked;
        this.rootForm = updatedForm;
    }

    // Field handlers
    handleFieldInputChange(event) {
        const field = event.target.dataset.field;
        this.fieldForm = { ...this.fieldForm, [field]: event.target.value };
    }
    handleFieldIncludeChange(event) {
        this.fieldForm = { ...this.fieldForm, include: event.target.checked };
    }

    async handleToggleInclude(event) {
        const devName = event.target.dataset.devname;
        const include = event.target.checked;
        try {
            this.loading = true;
            await upsertField({ input: { developerName: devName, parentDeveloperName: this.fieldsParent, fieldApiName: '', include } });
            await this.loadFields();
        } catch (e) {
            this.toast('Error', this.errorMessage(e), 'error');
        } finally { this.loading = false; }
    }

    get hasConfigs() {
        return Array.isArray(this.configs) && this.configs.length > 0;
    }

    get showEmptyState() {
        return !this.loading && (!this.objectApi || !this.hasConfigs);
    }
    get showTable() {
        return !this.loading && this.objectApi && this.hasConfigs;
    }

    async loadRecent() {
        try {
            const data = await listRecent({ maxResults: 10 });
            this.recent = (data || []).map(d => ({
                id: d.id,
                when: d.completedOn || d.createdDate,
                status: d.status,
                state: d.state,
                errorCount: d.errorCount,
                componentFullName: d.componentFullName,
                componentType: d.componentType,
                problem: d.problem,
                statusClass: (d.errorCount && d.errorCount > 0) ? 'slds-text-color_error' : 'slds-text-color_success'
            }));
        } catch (e) {
            // non-blocking
        }
    }

    get showMdapiWarning() {
        return this.mdapiReady === false;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    errorMessage(e) {
        try {
            if (e && e.body && e.body.message) return e.body.message;
            if (e && e.message) return e.message;
        } catch (ignore) {}
        return 'Unexpected error';
    }

    async pollConfigs(attempts, delayMs) {
        for (let i = 0; i < attempts; i++) {
            await this.sleep(delayMs);
            this.refresh();
            if (this.hasConfigs) break;
        }
    }
    sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
}
