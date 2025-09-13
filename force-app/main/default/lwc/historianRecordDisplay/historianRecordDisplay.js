import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getHistorianConfig from '@salesforce/apex/HistorianConfigAdminService.getHistorianConfigForObject';
import getHistorianRecords from '@salesforce/apex/HistorianConfigAdminService.getHistorianRecords';

export default class HistorianRecordDisplay extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track historianConfig;
    @track historianRecords = [];
    @track loading = true;
    @track error;
    @track expandedItems = new Set(); // Track which items are expanded

    connectedCallback() {
        console.log('=== HistorianRecordDisplay Connected ===');
        console.log('Initial recordId:', this.recordId);
        console.log('Initial objectApiName:', this.objectApiName);

        // If we already have both values, load immediately
        if (this.recordId && this.objectApiName) {
            console.log('Both recordId and objectApiName available, loading config immediately');
            this.loadHistorianConfig();
        }
    }
    
    // Timeline columns for datatable style
    @track timelineColumns = [
        { label: 'Date', fieldName: 'createdDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
        { label: 'Field', fieldName: 'fieldName', type: 'text' },
        { label: 'Old Value', fieldName: 'oldValue', type: 'text' },
        { label: 'New Value', fieldName: 'newValue', type: 'text' },
        { label: 'Changed By', fieldName: 'createdByName', type: 'text' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: ['Id'] })
    recordData({ error, data }) {
        console.log('=== HistorianRecordDisplay Wire Service ===');
        console.log('recordId:', this.recordId);
        console.log('objectApiName:', this.objectApiName);
        console.log('Wire data:', data);
        console.log('Wire error:', error);

        if (data) {
            console.log('Record data received, loading historian config...');
            this.loadHistorianConfig();
        } else if (error) {
            this.handleError('Error loading record data', error);
        }
    }

    async loadHistorianConfig() {
        console.log('=== loadHistorianConfig ===');
        try {
            this.loading = true;
            this.error = null;

            console.log('Calling getHistorianConfig with objectApiName:', this.objectApiName);

            // Get the historian configuration for this object
            const config = await getHistorianConfig({
                objectApiName: this.objectApiName
            });

            console.log('Config received:', JSON.stringify(config, null, 2));

            if (!config) {
                console.error('No historian configuration found');
                this.error = `No historian configuration found for ${this.objectApiName}`;
                return;
            }

            // Check if historyObjectApi is populated
            if (!config.historyObjectApi) {
                console.error('History Object API is not set in configuration');
                this.error = `History Object API is not configured for ${this.objectApiName}. Please ensure the historian object has been created.`;
                return;
            }

            this.historianConfig = config;
            console.log('Historian config set with history object:', config.historyObjectApi);
            console.log('Loading records...');
            await this.loadHistorianRecords();

        } catch (error) {
            console.error('Error in loadHistorianConfig:', error);
            this.handleError('Error loading historian configuration', error);
        } finally {
            this.loading = false;
        }
    }

    async loadHistorianRecords() {
        console.log('=== loadHistorianRecords ===');
        try {
            if (!this.historianConfig || !this.recordId) {
                console.log('Missing config or recordId:', {
                    config: this.historianConfig,
                    recordId: this.recordId
                });
                return;
            }

            const params = {
                recordId: this.recordId,
                configName: this.historianConfig.configName || this.historianConfig.developerName,
                objectApiName: this.objectApiName,
                maxResults: 100
            };
            console.log('Calling getHistorianRecords with params:', params);
            console.log('Full historian config:', this.historianConfig);

            const records = await getHistorianRecords(params);

            console.log('Raw records received:', records);
            console.log('Number of records:', records ? records.length : 0);

            // Log first record details if available
            if (records && records.length > 0) {
                console.log('First record details:', records[0]);
                console.log('Field names in first record:', Object.keys(records[0]));
            }

            // Transform records for display
            this.historianRecords = (records || []).map(record => {
                const createdById = record.CreatedBy?.Id;
                const transformed = {
                    id: record.Id,
                    createdDate: record.CreatedDate,
                    fieldName: record.Field_Changed_Label__c || record.Field_Changed_Api__c || 'Unknown Field',
                    oldValue: this.formatValue(record.Prior_Value__c),
                    newValue: this.formatValue(record.New_Value__c),
                    createdByName: record.CreatedBy?.Name || 'Unknown User',
                    createdById: createdById,
                    createdByUrl: createdById ? `/lightning/r/User/${createdById}/view` : '#',
                    recordId: record.Parent_Record__c,
                    changeType: this.determineChangeType(record.Prior_Value__c, record.New_Value__c)
                };
                console.log('Transformed record:', transformed);
                return transformed;
            });

            console.log('Final historianRecords:', this.historianRecords);
            console.log('hasRecords:', this.hasRecords);

        } catch (error) {
            console.error('Error in loadHistorianRecords:', error);
            this.handleError('Error loading historian records', error);
        }
    }

    formatValue(value) {
        if (value === null || value === undefined) {
            return '--';
        }
        if (typeof value === 'string' && value.trim() === '') {
            return '--';
        }
        return String(value);
    }

    determineChangeType(oldValue, newValue) {
        if (!oldValue && newValue) return 'created';
        if (oldValue && !newValue) return 'deleted';
        if (oldValue && newValue) return 'updated';
        return 'unknown';
    }

    get displayStyle() {
        const style = this.historianConfig?.trackingStyle || 'Timeline';
        console.log('Display style:', style);
        return style;
    }

    get isTimelineStyle() {
        const isTimeline = this.displayStyle === 'Timeline';
        console.log('Is timeline style?', isTimeline);
        console.log('Has records?', this.hasRecords);
        return isTimeline;
    }

    get isDatatableStyle() {
        return this.displayStyle === 'Datatable';
    }

    get isCompactCardsStyle() {
        return this.displayStyle === 'CompactCards';
    }

    get hasRecords() {
        return this.historianRecords && this.historianRecords.length > 0;
    }

    get noRecordsMessage() {
        if (this.loading) return '';
        if (this.error) return '';
        return `No history records found for this ${this.objectApiName} record.`;
    }

    get cardTitle() {
        const objectLabel = this.objectApiName || 'Record';
        return `${objectLabel} History`;
    }

    handleError(title, error) {
        console.error(title, error);
        this.error = this.extractErrorMessage(error);
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: this.error,
            variant: 'error'
        }));
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        if (typeof error === 'string') {
            return error;
        }
        return 'An unexpected error occurred';
    }

    // Timeline-specific getters
    get timelineItems() {
        if (!this.isTimelineStyle || !this.hasRecords) return [];

        const items = this.historianRecords.map((record, index) => ({
            ...record,
            formattedDate: this.formatDate(record.createdDate),
            iconName: this.getChangeIcon(record.changeType),
            iconVariant: this.getChangeVariant(record.changeType),
            createdByUrl: record.createdByUrl,
            hasOldValue: record.oldValue && record.oldValue !== '--',
            isExpanded: this.expandedItems.has(record.id),
            isFirst: index === 0
        }));

        console.log('Timeline items generated:', items);
        console.log('First timeline item detail:', items[0]);
        return items;
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleString();
    }

    getChangeIcon(changeType) {
        switch (changeType) {
            case 'created': return 'utility:add';
            case 'updated': return 'utility:edit';
            case 'deleted': return 'utility:delete';
            default: return 'utility:change';
        }
    }

    getChangeVariant(changeType) {
        switch (changeType) {
            case 'created': return 'success';
            case 'updated': return 'warning';
            case 'deleted': return 'error';
            default: return 'base';
        }
    }

    // Compact Cards-specific getters
    get compactCardItems() {
        if (!this.isCompactCardsStyle || !this.hasRecords) return [];

        return this.historianRecords.map(record => ({
            ...record,
            formattedDate: this.formatDate(record.createdDate),
            hasChange: record.oldValue !== record.newValue,
            changeDescription: this.getChangeDescription(record),
            createdByUrl: record.createdByUrl
        }));
    }

    getChangeDescription(record) {
        let description;
        if (record.changeType === 'created') {
            description = `${record.fieldName} was set to "${record.newValue}"`;
        } else if (record.changeType === 'deleted') {
            description = `${record.fieldName} was cleared (was "${record.oldValue}")`;
        } else {
            description = `${record.fieldName} changed from "${record.oldValue}" to "${record.newValue}"`;
        }

        // Truncate to 255 characters
        if (description.length > 255) {
            description = description.substring(0, 252) + '...';
        }
        return description;
    }

    // Handle expand/collapse of timeline items
    handleToggleExpand(event) {
        // Don't toggle if clicking on a link
        if (event.target.tagName === 'A') {
            return;
        }

        const itemId = event.currentTarget.dataset.itemId;
        if (this.expandedItems.has(itemId)) {
            this.expandedItems.delete(itemId);
        } else {
            this.expandedItems.add(itemId);
        }
        // Force re-render
        this.expandedItems = new Set(this.expandedItems);
    }
}