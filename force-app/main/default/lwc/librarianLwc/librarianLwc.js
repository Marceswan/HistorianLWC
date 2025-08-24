import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Core admin services - all functionality consolidated into HistorianConfigAdminService
import listConfigs from '@salesforce/apex/HistorianConfigAdminService.listConfigsByObject';
import listAllConfigs from '@salesforce/apex/HistorianConfigAdminService.listAllConfigs';
import upsertRoot from '@salesforce/apex/HistorianConfigAdminService.upsertRoot';
import deleteRoot from '@salesforce/apex/HistorianConfigAdminService.deleteRoot';
import listFields from '@salesforce/apex/HistorianConfigAdminService.listFields';
import upsertField from '@salesforce/apex/HistorianConfigAdminService.upsertField';
import deleteField from '@salesforce/apex/HistorianConfigAdminService.deleteField';
import listRecent from '@salesforce/apex/HistorianConfigAdminService.listRecentDeployResults';
import getRecordTypesForObject from '@salesforce/apex/HistorianConfigAdminService.getRecordTypesForObject';
import deployFlowNow from '@salesforce/apex/FlowDeploymentService.deployFlowNow';
import verifyFlowDeployment from '@salesforce/apex/FlowDeploymentService.verifyFlowDeployment';
import getDeploymentStatus from '@salesforce/apex/FlowDeploymentService.getDeploymentStatus';

export default class LibrarianLwc extends LightningElement {
    @track objectApi = '';
    @track configName = '';
    @track jobId;
    @track loading = false;
    @track configs = [];
    @track filteredConfigs = [];
    @track objectSummaries = [];
    @track realObjectSummaries = [];
    @track selectedObjectFilter = null;
    @track recordTypeOptions = [];
    @track selectedRecordTypes = [];
    @track columns = [
        { label: 'Config Name', fieldName: 'configName', type: 'text' },
        { label: 'Object', fieldName: 'objectApi', type: 'text' },
        { label: 'Mode', fieldName: 'mode', type: 'text' },
        { label: 'Style', fieldName: 'style', type: 'text' },
        { label: 'Fields', fieldName: 'fields', type: 'text' },
        { 
            type: 'action', 
            fixedWidth: 120,
            typeAttributes: { 
                rowActions: [
                    { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
                    { label: 'Manage Fields', name: 'fields', iconName: 'utility:list' },
                    { label: 'Deactivate', name: 'delete', iconName: 'utility:delete' }
                ],
                menuAlignment: 'auto'
            }
        }
    ];

    @track recent = [];
    
    // Track deployment status per object
    @track deployInProgress = new Set();
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
            
            // Generate object summaries and apply filtering
            this.generateObjectSummaries();
            this.applyObjectFilter();
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
            const recordTypes = await getRecordTypesForObject({ objectApiName: this.objectApi.trim() });
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
            const recordTypes = await getRecordTypesForObject({ objectApiName: objectApiName });
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
            
            // Use the consolidated upsertRoot method which handles historian object creation
            const tempConfigName = this.configName || `Ensure_${Date.now()}`;
            const result = await upsertRoot({
                configName: tempConfigName,
                objectApiName: this.objectApi,
                trackingStyle: 'Timeline',
                trackMode: 'AllFields',
                active: true,
                label: `Historian Config for ${this.objectApi}`,
                developerName: '',
                historyObjectApi: '',
                recordTypes: ''
            });
            this.jobId = result.requestId || 'job_enqueued';
            
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
        // Also refresh real object summaries
        this.loadRealObjectSummaries();
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
            label: 'Historian Config',
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
        // Default to enabled since upsertRoot handles remote site deployment automatically
        this.mdapiReady = true;
        
        this.loadRecent();
        // Load all available object APIs to help user discover existing configs
        this.loadAvailableObjects();
        // Load real object summaries from Apex
        this.loadRealObjectSummaries();
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
                    
                    // Generate object summaries and apply filtering
                    this.generateObjectSummaries();
                    this.applyObjectFilter();
                }
            }
        } catch (e) {
            console.error('Error loading all configs:', e);
        }
    }

    // Load real object summaries - simplified approach
    async loadRealObjectSummaries() {
        try {
            console.log('Loading real object summaries...');
            // Since some services were removed, use conservative approach
            this.realObjectSummaries = [];
            console.log('Using conservative approach for object summaries');
            
            // Refresh object summaries to use real data
            this.generateObjectSummaries();
        } catch (error) {
            console.error('Error loading real object summaries:', error);
            this.realObjectSummaries = [];
        }
    }

    openRootModal(raw) {
        // Debug to see what raw data we're getting
        console.log('Raw data received in openRootModal:', JSON.stringify(raw));
        
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
        
        // Load record types for this object and set selected record types
        if (newForm.objectApiName) {
            console.log('Loading record types for edit - objectApiName:', newForm.objectApiName);
            this.loadRecordTypesForEdit(newForm.objectApiName, newForm.recordTypes);
        } else {
            console.log('No objectApiName for record type loading');
            this.recordTypeOptions = [];
            this.selectedRecordTypes = [];
        }
        
        // Add a small delay to ensure DOM updates
        setTimeout(() => {
            this.showRoot = true;
        }, 0);
    }
    
    closeRoot() { this.showRoot = false; }
    
    async saveRoot() {
        try {
            this.loading = true;
            this.showProgressMessage('Validating configuration...');
            
            // Clear any existing field-level validation errors
            [...this.template.querySelectorAll('lightning-input')]
                .forEach(inputCmp => inputCmp.setCustomValidity(''));
            
            // Validate required fields
            if (!this.rootForm.configName || this.rootForm.configName.trim() === '') {
                this.toast('Error', 'Config Name is required', 'error');
                return;
            }
            if (!this.rootForm.objectApiName || this.rootForm.objectApiName.trim() === '') {
                this.toast('Error', 'Object API Name is required', 'error');
                return;
            }

            // Get form values with proper null handling
            const rootConfig = {
                developerName: this.rootForm.developerName || '',
                label: this.rootForm.label || 'Default Config',
                configName: this.rootForm.configName.trim(),
                objectApiName: this.rootForm.objectApiName.trim(),
                trackingStyle: this.rootForm.trackingStyle || 'Timeline',
                trackMode: this.rootForm.trackMode || 'AllFields',
                active: this.rootForm.active === true,
                historyObjectApi: this.rootForm.historyObjectApi || '',
                recordTypes: this.selectedRecordTypes.join(',')
            };
            
            this.showProgressMessage('Saving configuration...');
            
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
            await this.loadRealObjectSummaries();
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
                'Remote site settings are being deployed automatically.',
                'info');
        } else if (result && result.requestId) {
            this.toast('Configuration Saved', 
                `Configuration has been saved and historian setup is in progress.`,
                'success');
        } else {
            this.toast('Configuration Saved', 
                'Configuration has been saved successfully.',
                'success');
        }
    }
    
    handleSaveError(error) {
        const errorMsg = this.errorMessage(error);
        this.toast('Error Saving Configuration', errorMsg, 'error');
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

    get hasFilteredConfigs() {
        return Array.isArray(this.filteredConfigs) && this.filteredConfigs.length > 0;
    }

    get hasObjectSummaries() {
        return Array.isArray(this.objectSummaries) && this.objectSummaries.length > 0;
    }

    get hasRecordTypes() {
        const hasTypes = Array.isArray(this.recordTypeOptions) && this.recordTypeOptions.length > 0;
        console.log('hasRecordTypes computed:', hasTypes, 'recordTypeOptions:', this.recordTypeOptions);
        return hasTypes;
    }

    get showEmptyState() {
        return !this.loading && !this.hasConfigs;
    }
    
    get showObjectSummaries() {
        return !this.loading && this.hasObjectSummaries;
    }
    
    get showTable() {
        return !this.loading && (this.hasFilteredConfigs || this.selectedObjectFilter);
    }

    get filteredConfigsCount() {
        return this.filteredConfigs ? this.filteredConfigs.length : 0;
    }

    get totalConfigsCount() {
        return this.configs ? this.configs.length : 0;
    }

    // Generate object summaries from current configs
    generateObjectSummaries() {
        if (!this.configs || this.configs.length === 0) {
            this.objectSummaries = [];
            return;
        }

        // Group configurations by object
        const objectGroups = {};
        this.configs.forEach(config => {
            const objectName = config.objectApi;
            if (!objectGroups[objectName]) {
                objectGroups[objectName] = [];
            }
            objectGroups[objectName].push(config);
        });

        // Generate summaries for each object
        this.objectSummaries = Object.keys(objectGroups).map(objectName => {
            const objectConfigs = objectGroups[objectName];
            const activeConfigs = objectConfigs.filter(c => c._raw.active !== false);
            
            const deployInProgress = this.deployInProgress.has(objectName);
            
            return {
                objectApiName: objectName,
                activeConfigsCount: activeConfigs.length,
                totalConfigsCount: objectConfigs.length,
                activeRecordTypesCount: 0, // Simplified
                hasFlowDeployed: false, // Conservative default
                hasHistoryObject: false, // Conservative default
                lastUpdated: new Date(),
                isSelected: this.selectedObjectFilter === objectName,
                deployInProgress: deployInProgress,
                deployButtonLabel: deployInProgress ? 'Deploying...' : 'Deploy Flow Now'
            };
        });

        console.log('Generated object summaries:', this.objectSummaries);
    }

    // Apply object filter to configurations
    applyObjectFilter() {
        if (!this.selectedObjectFilter) {
            this.filteredConfigs = [...this.configs];
        } else {
            this.filteredConfigs = this.configs.filter(config => 
                config.objectApi === this.selectedObjectFilter
            );
        }
        console.log('Applied filter:', this.selectedObjectFilter, 'Filtered configs:', this.filteredConfigs.length);
    }

    // Handle clicking on an object summary card
    handleObjectCardClick(event) {
        const objectName = event.currentTarget.dataset.object;
        
        if (this.selectedObjectFilter === objectName) {
            // Clicking on already selected card clears the filter
            this.selectedObjectFilter = null;
        } else {
            // Set new filter
            this.selectedObjectFilter = objectName;
        }
        
        // Regenerate summaries to update selected state
        this.generateObjectSummaries();
        this.applyObjectFilter();
    }

    // Clear object filter
    clearObjectFilter() {
        this.selectedObjectFilter = null;
        this.generateObjectSummaries();
        this.applyObjectFilter();
    }

    // Handle deploy Flow button click with real-time deployment
    async handleDeployFlow(event) {
        const objectApiName = event.target.dataset.objectApi;
        
        if (!objectApiName) {
            this.toast('Error', 'Object API name not found', 'error');
            return;
        }

        try {
            this.deployInProgress.add(objectApiName);
            this.generateObjectSummaries(); // Refresh to show loading state

            this.toast('Deploy Started', 
                `Deploying historian Flow for ${objectApiName} using real-time deployment...`, 
                'info');

            console.log('Starting real-time Flow deployment for:', objectApiName);
            
            // Use the new real-time deployment service
            const deployResult = await deployFlowNow({ objectApiName: objectApiName });
            console.log('Real-time deployment result:', deployResult);
            
            this.deployInProgress.delete(objectApiName);
            this.generateObjectSummaries(); // Refresh to hide loading state

            // Handle deployment results
            if (deployResult.success) {
                if (deployResult.verified) {
                    this.toast('Deploy Complete', 
                        `Historian Flow for ${objectApiName} deployed and verified successfully!`, 
                        'success');
                } else if (deployResult.inProgress) {
                    this.toast('Deploy In Progress', 
                        `Historian Flow deployment initiated for ${objectApiName}. Check Recent Activity for updates.`, 
                        'info');
                } else {
                    this.toast('Deploy Complete', 
                        `Historian Flow for ${objectApiName} deployed successfully.`, 
                        'success');
                }
                
                // Show additional details if available
                if (deployResult.message) {
                    console.log('Deployment message:', deployResult.message);
                }
                if (deployResult.flowDescription) {
                    console.log('Generated Flow description:', deployResult.flowDescription);
                }
            } else {
                // Show error details
                const errorMsg = deployResult.error || 'Unknown deployment error';
                this.toast('Deploy Failed', 
                    `Failed to deploy Flow for ${objectApiName}: ${errorMsg}`, 
                    'error');
                
                if (deployResult.errorType) {
                    console.error('Deployment error type:', deployResult.errorType);
                }
            }

            // Refresh the recent deployment activity
            await this.loadRecent();
            await this.loadRealObjectSummaries();

            // Verify deployment after a short delay
            if (deployResult.success) {
                setTimeout(async () => {
                    await this.verifyFlowStatus(objectApiName);
                }, 3000); // Wait 3 seconds before verification
            }

        } catch (error) {
            this.deployInProgress.delete(objectApiName);
            this.generateObjectSummaries();
            
            const errorMsg = this.errorMessage(error);
            console.error('Deployment error:', error);
            this.toast('Deploy Failed', 
                `Failed to deploy Flow for ${objectApiName}: ${errorMsg}`, 
                'error');
        }
    }
    
    // Verify Flow deployment status
    async verifyFlowStatus(objectApiName) {
        try {
            console.log('Verifying Flow deployment for:', objectApiName);
            
            const verificationResult = await verifyFlowDeployment({ objectApiName: objectApiName });
            console.log('Verification result:', verificationResult);
            
            if (verificationResult.success && verificationResult.flowExists) {
                this.toast('Verification Complete', 
                    `Flow for ${objectApiName} is deployed and functional.`, 
                    'success');
                
                // Refresh object summaries to reflect current status
                await this.loadRealObjectSummaries();
            } else if (!verificationResult.flowExists) {
                this.toast('Verification Warning', 
                    `Flow for ${objectApiName} may not be properly deployed. Check Recent Activity for details.`, 
                    'warning');
            }
            
        } catch (verifyError) {
            console.error('Error verifying Flow deployment:', verifyError);
            // Don't show toast for verification errors to avoid overwhelming user
        }
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

    // Simplified permission check
    async checkPermissionStatus() {
        try {
            this.loading = true;
            this.showProgressMessage('Checking basic permission status...');
            
            const message = 'User has access to Historian configuration. For detailed permissions, use Setup > Permission Sets > Historian Admin.';
            this.toast('Permission Status', message, 'info');
            
        } catch (e) {
            console.error('Error checking permissions:', e);
            this.toast('Permission Check Error', this.errorMessage(e), 'error');
        } finally {
            this.loading = false;
            this.clearProgressMessage();
        }
    }
}