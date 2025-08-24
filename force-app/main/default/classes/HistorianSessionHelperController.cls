public with sharing class HistorianSessionHelperController {
    
    public String getMetadataEndpoint() {
        return MdapiUtil.metadataEndpoint();
    }
    
    public String getSessionId() {
        return UserInfo.getSessionId();
    }
    
    public String getApiVersion() {
        return MdapiUtil.API_VERSION;
    }
}