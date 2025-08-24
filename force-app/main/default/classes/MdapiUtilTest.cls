@IsTest
private class MdapiUtilTest {
    @IsTest
    static void testEndpointFormat() {
        String ep = MdapiUtil.metadataEndpoint();
        System.assert(ep.contains('/services/Soap/m/'), 'Endpoint should point to metadata SOAP path');
    }
}

