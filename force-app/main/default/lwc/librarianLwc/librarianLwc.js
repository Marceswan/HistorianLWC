import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import startEnsure from '@salesforce/apex/HistorianAdminController.startEnsureHistorianObject';
import listConfigs from '@salesforce/apex/HistorianConfigAdminService.listConfigsByObject';
import listAllConfigs from '@salesforce/apex/HistorianConfigAdminService.listAllConfigs';
import upsertRoot from '@salesforce/apex/HistorianConfigAdminService.upsertRoot';
import deleteRoot from '@salesforce/apex/HistorianConfigAdminService.deleteRoot';
import listFields from '@salesforce/apex/HistorianConfigAdminService.listFields';
import upsertField from '@salesforce/apex/HistorianConfigAdminService.upsertField';
import deleteField from '@salesforce/apex/HistorianConfigAdminService.deleteField';
import listRecent from '@salesforce/apex/HistorianConfigAdminService.listRecentDeployResults';
import mdapiRemoteSiteOk from '@salesforce/apex/HistorianSetupService.mdapiRemoteSiteOk';
import isHistorianProvisioned from '@salesforce/apex/HistorianAdminController.isHistorianProvisioned';
import getRecordTypes from '@salesforce/apex/HistorianAdminController.getRecordTypes';

export default class LibrarianLwc extends LightningElement {
    @track objectApi = '';
    @track configName = '';
    @track jobId;
    @track loading = false;
    @track configs = [];
    @track recordTypeOptions = [];
    @track selectedRecordTypes = [];
    @track columns = [
        { label: 'Config Name', fieldName: 'configName', type: 'text', fixedWidth: 150 },
        { label: 'Object', fieldName: 'objectApi', type: 'text', fixedWidth: 120 },
        { label: 'Mode', fieldName: 'mode', type: 'text', fixedWidth: 100 },
        { label: 'Style', fieldName: 'style', type: 'text', fixedWidth: 100 },
        { label: 'Fields', fieldName: 'fields', type: 'text', fixedWidth: 80 },
        { 
            type: 'action', 
            fixedWidth: 120,
            typeAttributes: { 
                rowActions: [
                    { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
                    { label: 'Manage Fields', name: 'fields', iconName: 'utility:list' },
                    { label: 'Deactivate', name: 'delete', iconName: 'utility:delete' }
                ],
                menuAlignment: 'right'
            }
        }
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
                style: c.style || 'Timeline',
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
        // Clear existing record type selections when object changes
        this.recordTypeOptions = [];
        this.selectedRecordTypes = [];
        // Load record types for the new object
        this.loadRecordTypes();
        this.refresh();
    }
    handleConfigChange(event) {
        this.configName = event.target.value;
    }

    // Load record types for the current object
    async loadRecordTypes() {
        if (!this.objectApi || this.objectApi.trim() === '') {
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
            return;
        }

        try {
            const recordTypes = await getRecordTypes({ objectApiName: this.objectApi.trim() });
            this.recordTypeOptions = recordTypes || [];
            
            // Default to "All Record Types" if available, otherwise select nothing
            if (this.recordTypeOptions.length > 0 && 
                this.recordTypeOptions[0].value === 'ALL_RECORD_TYPES') {
                this.selectedRecordTypes = ['ALL_RECORD_TYPES'];
            } else {
                this.selectedRecordTypes = [];
            }
        } catch (error) {
            console.error('Error loading record types:', error);
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
            this.toast('Warning', 'Could not load record types for this object', 'warning');
        }
    }

    // Handle record type selection changes
    handleRecordTypeChange(event) {
        this.selectedRecordTypes = event.detail.value;
    }

    // Load record types for editing an existing config
    async loadRecordTypesForEdit(objectApiName, existingRecordTypes) {
        try {
            console.log('loadRecordTypesForEdit called with:', objectApiName, existingRecordTypes);
            const recordTypes = await getRecordTypes({ objectApiName: objectApiName });
            console.log('Record types returned from Apex:', recordTypes);
            this.recordTypeOptions = recordTypes || [];
            console.log('recordTypeOptions set to:', this.recordTypeOptions);
            console.log('hasRecordTypes computed property:', this.hasRecordTypes);
            
            // Set selected record types based on existing configuration
            if (existingRecordTypes && typeof existingRecordTypes === 'string' && existingRecordTypes.trim() !== '') {
                // Convert comma-separated string to array
                this.selectedRecordTypes = existingRecordTypes.split(',').map(rt => rt.trim()).filter(rt => rt);
                console.log('Set selectedRecordTypes from string:', this.selectedRecordTypes);
            } else if (existingRecordTypes && Array.isArray(existingRecordTypes) && existingRecordTypes.length > 0) {
                // Handle if it's already an array
                this.selectedRecordTypes = existingRecordTypes;
                console.log('Set selectedRecordTypes from array:', this.selectedRecordTypes);
            } else {
                // Default to "All Record Types" if no existing selection and it's available
                if (this.recordTypeOptions.length > 0 && 
                    this.recordTypeOptions[0].value === 'ALL_RECORD_TYPES') {
                    this.selectedRecordTypes = ['ALL_RECORD_TYPES'];
                    console.log('Set selectedRecordTypes to ALL_RECORD_TYPES default');
                } else {
                    this.selectedRecordTypes = [];
                    console.log('Set selectedRecordTypes to empty array');
                }
            }
            
            // Force re-render by updating the tracked properties
            this.recordTypeOptions = [...this.recordTypeOptions];
            this.selectedRecordTypes = [...this.selectedRecordTypes];
        } catch (error) {
            console.error('Error loading record types for edit:', error);
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
        }
    }
    async ensureHistorian() {
        try {
            this.loading = true;
            this.showProgressMessage('Ensuring historian object exists...');
            
            // Validate inputs
            if (!this.objectApi || this.objectApi.trim() === '') {
                this.toast('Error', 'Object API Name is required', 'error');
                return;
            }
            
            // Check remote site settings first
            if (this.mdapiReady === false) {
                this.toast('Remote Site Configuration Required', 
                    'Remote site settings need to be configured before creating historian objects. Use the "Remote Site Helper" button to configure them.',
                    'warning');
                return;
            }
            
            this.jobId = await startEnsure({ objectApi: this.objectApi, configName: this.configName });
            this.toast('Historian Job Enqueued', `Job Id: ${this.jobId}`, 'success');
            await this.loadRecent();
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
            this.handleEnsureHistorianError(e);
        } finally { 
            this.loading = false;
            this.clearProgressMessage();
        }
    }
    
    handleEnsureHistorianError(error) {
        const errorMsg = this.errorMessage(error);
        
        if (errorMsg.includes('Remote site')) {
            this.toast('Remote Site Configuration Required', 
                'Remote site settings need to be configured. Use the "Remote Site Helper" button.',
                'error');
        } else if (errorMsg.includes('does not exist')) {
            this.toast('Invalid Object', 
                'The specified object does not exist in this org.',
                'error');
        } else {
            this.toast('Error', errorMsg, 'error');
        }
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
    @track rootForm = { developerName: '', label: '', configName: '', objectApiName: '', trackingStyle: 'Timeline', trackMode: 'AllFields', active: true, historyObjectApi: '', recordTypes: [] };
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
            historyObjectApi: '',
            recordTypes: []
        };
        
        // Load record types for the current object if available
        if (this.objectApi) {
            this.loadRecordTypes();
        } else {
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
        }
        
        this.showRoot = true;
    }
    connectedCallback() {
        // Probe mdapi remote site readiness
        this.checkRemoteSiteReadiness();
        this.loadRecent();
        // Load all available object APIs to help user discover existing configs
        this.loadAvailableObjects();
    }
    
    async checkRemoteSiteReadiness() {
        try {
            const ok = await mdapiRemoteSiteOk();
            this.mdapiReady = ok;
            if (!ok) {
                console.warn('Remote site settings not configured - historian object creation will be limited');
            }
        } catch (error) {
            console.error('Error checking remote site settings:', error);
            this.mdapiReady = false;
            // Don't show error toast here as this is a background check
        }
    }
    
    async loadAvailableObjects() {
        try {
            // Load all configs when no specific object API is set
            if (!this.objectApi) {
                const allConfigs = await listAllConfigs();
                if (allConfigs && allConfigs.length > 0) {
                    this.configs = allConfigs.map(c => ({
                        id: `${c.objectApiName}:${c.configName}`,
                        configName: c.configName,
                        objectApi: c.objectApiName,
                        mode: c.trackMode === 'AllFields' ? 'All Fields' : 'Per Field',
                        style: c.style || 'Timeline',
                        fields: '—',
                        _raw: c
                    }));
                    console.log('Loaded all configs:', this.configs.length);
                }
            }
        } catch (e) {
            console.error('Error loading all configs:', e);
        }
    }
    openRootModal(raw) {
        // Debug to see what raw data we're getting
        console.log('Raw data received in openRootModal:', JSON.stringify(raw));
        
        // When editing, ensure all fields are properly mapped from CMDT values
        // Map the raw CMDT data to form fields correctly
        const newForm = {
            developerName: raw.developerName || '',
            label: raw.label || '',
            configName: raw.configName || '',
            objectApiName: raw.objectApiName || '',
            style: raw.style || 'Timeline',
            trackMode: raw.trackMode || 'AllFields', 
            active: raw.active !== undefined ? raw.active : true,
            historyObjectApi: raw.historyObjectApi || '',
            recordTypes: raw.recordTypes || []
        };
        
        // Force reactivity by reassigning the entire tracked object
        this.rootForm = { ...newForm };
        
        console.log('rootForm after mapping from CMDT:', JSON.stringify(this.rootForm));
        console.log('Mapped values - style:', this.rootForm.style, 'trackMode:', this.rootForm.trackMode);
        
        // Load record types for this object and set selected record types
        if (newForm.objectApiName) {
            console.log('Loading record types for edit - objectApiName:', newForm.objectApiName);
            this.loadRecordTypesForEdit(newForm.objectApiName, newForm.recordTypes);
        } else {
            console.log('No objectApiName for record type loading');
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
        }
        
        // Check if historian object exists for this config
        this.checkHistorianObjectExists(raw.objectApiName);
        
        // Add a small delay to ensure DOM updates
        setTimeout(() => {
            this.showRoot = true;
        }, 0);
    }
    
    async checkHistorianObjectExists(objectApiName) {
        if (objectApiName) {
            try {
                const exists = await isHistorianProvisioned({ objectApi: objectApiName });
                if (!exists) {
                    console.log(`Historian object for ${objectApiName} does not exist - will be created on save`);
                    this.toast('Info', `Historian object for ${objectApiName} will be created when you save`, 'info');
                }
            } catch (e) {
                console.error('Error checking historian object:', e);
            }
        }
    }
    closeRoot() { this.showRoot = false; }
    async saveRoot() {
        try {
            this.loading = true;
            this.showProgressMessage('Validating configuration...');
            
            // Clear any existing field-level validation errors
            [...this.template.querySelectorAll('lightning-input')]
                .forEach(inputCmp => inputCmp.setCustomValidity(''));
            
            // Log rootForm to see current values before validation
            console.log('PRE-VALIDATION rootForm:', JSON.stringify(this.rootForm));
            console.log('configName type:', typeof this.rootForm.configName);
            console.log('configName value:', this.rootForm.configName);
            console.log('configName length:', this.rootForm.configName ? this.rootForm.configName.length : 'undefined');
            console.log('objectApiName value:', this.rootForm.objectApiName);
            console.log('trackingStyle value:', this.rootForm.trackingStyle);
            console.log('trackMode value:', this.rootForm.trackMode);
            console.log('active value:', this.rootForm.active);
            
            // Additional validation for trimmed values
            if (!this.rootForm.configName || this.rootForm.configName.trim() === '') {
                console.log('CLIENT VALIDATION FAILED - configName is empty');
                this.toast('Error', 'Config Name is required', 'error');
                return;
            }
            if (!this.rootForm.objectApiName || this.rootForm.objectApiName.trim() === '') {
                console.log('CLIENT VALIDATION FAILED - objectApiName is empty');
                this.toast('Error', 'Object API Name is required', 'error');
                return;
            }

            // Validate record type selections
            if (this.selectedRecordTypes && this.selectedRecordTypes.length > 0) {
                const validRecordTypeValues = (this.recordTypeOptions || []).map(option => option.value);
                const invalidSelections = this.selectedRecordTypes.filter(selected => 
                    !validRecordTypeValues.includes(selected)
                );
                
                if (invalidSelections.length > 0) {
                    console.log('CLIENT VALIDATION FAILED - invalid record type selections:', invalidSelections);
                    this.toast('Error', `Invalid record type selections: ${invalidSelections.join(', ')}`, 'error');
                    return;
                }
            }
            
            console.log('CLIENT VALIDATION PASSED');
            
            // Debug rootForm before creating rootConfig object
            console.log('rootForm.configName before creation:', this.rootForm.configName);
            console.log('rootForm.objectApiName before creation:', this.rootForm.objectApiName);
            console.log('Entire rootForm object:', this.rootForm);
            
            // Get form values directly from DOM elements to ensure we have the latest values
            const configNameInput = this.template.querySelector('lightning-input[data-field="configName"]');
            const objectApiNameInput = this.template.querySelector('lightning-input[data-field="objectApiName"]');
            const trackModeCombo = this.template.querySelector('lightning-combobox[label="Track Mode"]');
            const trackStyleCombo = this.template.querySelector('lightning-combobox[label="Style"]');
            const activeCheckbox = this.template.querySelector('lightning-input[label="Active"]');
            
            console.log('DOM Elements Found:');
            console.log('configNameInput:', configNameInput);
            console.log('objectApiNameInput:', objectApiNameInput);
            console.log('trackModeCombo:', trackModeCombo);
            console.log('trackStyleCombo:', trackStyleCombo);
            console.log('activeCheckbox:', activeCheckbox);
            
            // Extract values, ensuring we never pass string "null" values
            const configNameValue = configNameInput && configNameInput.value ? configNameInput.value.trim() : 
                                   (this.rootForm.configName && this.rootForm.configName !== 'null' ? this.rootForm.configName.trim() : '');
            const objectApiNameValue = objectApiNameInput && objectApiNameInput.value ? objectApiNameInput.value.trim() : 
                                      (this.rootForm.objectApiName && this.rootForm.objectApiName !== 'null' ? this.rootForm.objectApiName.trim() : '');
            const trackModeValue = trackModeCombo && trackModeCombo.value ? trackModeCombo.value : 
                                  (this.rootForm.trackMode && this.rootForm.trackMode !== 'null' ? this.rootForm.trackMode : 'AllFields');
            const trackStyleValue = trackStyleCombo && trackStyleCombo.value ? trackStyleCombo.value : 
                                   (this.rootForm.trackingStyle && this.rootForm.trackingStyle !== 'null' ? this.rootForm.trackingStyle : 'Timeline');
            const activeValue = activeCheckbox ? activeCheckbox.checked : (this.rootForm.active === true);
            
            console.log('Extracted Values:');
            console.log('configNameValue:', configNameValue);
            console.log('objectApiNameValue:', objectApiNameValue);
            console.log('trackModeValue:', trackModeValue);
            console.log('trackStyleValue:', trackStyleValue);
            console.log('activeValue:', activeValue);
            
            // Create a clean object matching the Apex DTO structure
            const rootConfig = {
                developerName: this.rootForm.developerName || '',
                label: this.rootForm.label || 'Default Config',
                configName: configNameValue,
                objectApiName: objectApiNameValue,
                trackingStyle: trackStyleValue,
                trackMode: trackModeValue,
                active: activeValue,
                historyObjectApi: this.rootForm.historyObjectApi || '',
                requestId: null
            };
            
            console.log('RootConfig object created:', JSON.stringify(rootConfig));
            console.log('Calling Apex upsertRoot with rootConfig as input parameter');
            console.log('About to call upsertRoot with params:', JSON.stringify(rootConfig));
            
            this.showProgressMessage('Saving configuration...');
            
            // Call Apex method with individual parameters to avoid DTO serialization issues
            console.log('Final rootConfig for Apex:', JSON.stringify(rootConfig));
            console.log('configName being sent:', rootConfig.configName);
            console.log('objectApiName being sent:', rootConfig.objectApiName);
            
            // Convert selected record types array to comma-separated string
            rootConfig.recordTypes = this.selectedRecordTypes.join(',');

            // Call Apex method with individual parameters
            const result = await upsertRoot({ 
                configName: rootConfig.configName,
                objectApiName: rootConfig.objectApiName,
                trackingStyle: rootConfig.trackingStyle,
                trackMode: rootConfig.trackMode,
                active: rootConfig.active,
                label: rootConfig.label,
                developerName: rootConfig.developerName,
                historyObjectApi: rootConfig.historyObjectApi,
                recordTypes: rootConfig.recordTypes
            });
            
            console.log('Apex response:', result);
            
            // Handle different response scenarios
            this.handleSaveSuccess(result, rootConfig);
            this.showRoot = false;
            await this.pollConfigs(8, 800);
            await this.loadRecent();
        } catch (e) {
            console.error('Error in saveRoot:', e);
            this.handleSaveError(e);
        } finally { 
            this.loading = false; 
            this.clearProgressMessage();
        }
    }
    
    handleSaveSuccess(result, rootConfig) {
        if (result && result.requestId === 'REMOTE_SITE_DEPLOYING') {
            this.toast('Remote Site Settings Deploying', 
                'Remote site settings are being deployed automatically. The historian object will be created once deployment completes. Please check back in a few minutes.',
                'info');
        } else if (result && result.requestId) {
            this.toast('Configuration Saved', 
                `Configuration has been saved and historian object creation is in progress (Job ID: ${result.requestId.substring(0, 15)}...)`,
                'success');
        } else {
            this.toast('Configuration Saved', 
                'Configuration has been saved successfully. Historian object already exists or was created.',
                'success');
        }
    }
    
    handleSaveError(error) {
        const errorMsg = this.errorMessage(error);
        
        // Detect specific error types and provide tailored messages
        if (errorMsg.includes('Remote site settings')) {
            this.toast('Remote Site Configuration Required', 
                'Remote site settings need to be configured before creating historian objects. Please configure them manually or contact your administrator.',
                'error');
        } else if (errorMsg.includes('historian object') && errorMsg.includes('saved')) {
            this.toast('Partial Success', 
                'Configuration was saved but historian object creation failed. You may need to create the historian object manually.',
                'warning');
        } else if (errorMsg.includes('System limits exceeded')) {
            this.toast('System Busy', 
                'The system is currently at capacity. Please try again in a few minutes.',
                'warning');
        } else if (errorMsg.includes('too many active jobs')) {
            this.toast('Too Many Background Jobs', 
                'There are too many background processes running. Please wait a few minutes and try again.',
                'warning');
        } else if (errorMsg.includes('does not exist')) {
            this.toast('Invalid Object', 
                'The specified object does not exist in this org. Please check the Object API Name.',
                'error');
        } else {
            this.toast('Error Saving Configuration', errorMsg, 'error');
        }
    }
    
    @track progressMessage = '';
    
    showProgressMessage(message) {
        this.progressMessage = message;
    }
    
    clearProgressMessage() {
        this.progressMessage = '';
    }
    
    get isShowingProgress() {
        return this.loading && this.progressMessage;
    }
    async removeRoot(raw) {
        try {
            this.loading = true;
            await deleteRoot({ developerName: raw.developerName });
            this.toast('Deactivated', 'Configuration has been deactivated (set to inactive)', 'success');
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

        // If object API name changes, clear and reload record types
        if (field === 'objectApiName') {
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
            this.loadRecordTypes();
        }
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

    get hasRecordTypes() {
        const hasTypes = Array.isArray(this.recordTypeOptions) && this.recordTypeOptions.length > 0;
        console.log('hasRecordTypes computed:', hasTypes, 'recordTypeOptions:', this.recordTypeOptions);
        return hasTypes;
    }

    get showEmptyState() {
        return !this.loading && !this.hasConfigs;
    }
    get showTable() {
        return !this.loading && this.hasConfigs;
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
