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
        if (data) {
            this.loadHistorianConfig();
        } else if (error) {
            this.handleError('Error loading record data', error);
        }
    }

    async loadHistorianConfig() {
        try {
            this.loading = true;
            this.error = null;
            
            // Get the historian configuration for this object
            const config = await getHistorianConfig({ 
                objectApiName: this.objectApiName 
            });
            
            if (!config) {
                this.error = `No historian configuration found for ${this.objectApiName}`;
                return;
            }
            
            this.historianConfig = config;
            await this.loadHistorianRecords();
            
        } catch (error) {
            this.handleError('Error loading historian configuration', error);
        } finally {
            this.loading = false;
        }
    }

    async loadHistorianRecords() {
        try {
            if (!this.historianConfig || !this.recordId) {
                return;
            }
            
            const records = await getHistorianRecords({
                recordId: this.recordId,
                configName: this.historianConfig.configName,
                objectApiName: this.objectApiName,
                maxResults: 100
            });
            
            // Transform records for display
            this.historianRecords = (records || []).map(record => ({
                id: record.Id,
                createdDate: record.CreatedDate,
                fieldName: record.Field_Name__c || 'Unknown Field',
                oldValue: this.formatValue(record.Old_Value__c),
                newValue: this.formatValue(record.New_Value__c),
                createdByName: record.CreatedBy?.Name || 'Unknown User',
                createdById: record.CreatedBy?.Id,
                recordId: record.Parent_Record_Id__c,
                changeType: this.determineChangeType(record.Old_Value__c, record.New_Value__c)
            }));
            
        } catch (error) {
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
        return this.historianConfig?.trackingStyle || 'Timeline';
    }

    get isTimelineStyle() {
        return this.displayStyle === 'Timeline';
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
        
        return this.historianRecords.map(record => ({
            ...record,
            formattedDate: this.formatDate(record.createdDate),
            iconName: this.getChangeIcon(record.changeType),
            iconVariant: this.getChangeVariant(record.changeType)
        }));
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
            changeDescription: this.getChangeDescription(record)
        }));
    }

    getChangeDescription(record) {
        if (record.changeType === 'created') {
            return `${record.fieldName} was set to "${record.newValue}"`;
        }
        if (record.changeType === 'deleted') {
            return `${record.fieldName} was cleared (was "${record.oldValue}")`;
        }
        return `${record.fieldName} changed from "${record.oldValue}" to "${record.newValue}"`;
    }
}