import { LightningElement, api, track, wire } from 'lwc';
import listConfigs from '@salesforce/apex/HistorianConfigService.listActiveConfigs';

export default class HistorianFlowEditor extends LightningElement {
    @api availableActions; // Flow wiring
    @api builderContext;
    @api properties; // holds TargetSObjectApiName and ConfigName

    @track objectApi;
    @track configName;
    @track configs = [];

    @wire(listConfigs, { objectApi: '$objectApi' })
    wiredConfigs({ data, error }) {
        if (data) this.configs = data.map(c => ({ label: c.configName, value: c.configName, detail: c }));
        // eslint-disable-next-line no-console
        if (error) console.error(error);
    }

    connectedCallback() {
        this.objectApi = this.properties?.TargetSObjectApiName;
        this.configName = this.properties?.ConfigName;
    }

    handleObjectChange(event) {
        this.objectApi = event.detail.value;
        this.notifyChange('TargetSObjectApiName', this.objectApi);
    }

    handleConfigChange(event) {
        this.configName = event.detail.value;
        this.notifyChange('ConfigName', this.configName);
    }

    notifyChange(name, value) {
        this.dispatchEvent(new CustomEvent('configuration_editor_input_value_changed', {
            bubbles: true,
            cancelable: false,
            composed: true,
            detail: { name, newValue: value }
        }));
    }
}
