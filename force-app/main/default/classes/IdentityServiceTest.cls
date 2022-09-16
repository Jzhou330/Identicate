@isTest
public class IdentityServiceTest{

    @TestSetup
    static void testSetup(){
        createIdentity(true);
    }
    
    static testMethod void saveFiles_Negative_Test(){
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion], '0 ContentVersions should exist');
        
        Test.startTest();
        try{
            IdentityService.saveFiles(null);    
        }
        catch(AuraHandledException ahe){
            System.assertEquals('fileWrapperListJSON can\'t be null', ahe.getMessage());
        }
        Test.stopTest();
        
		System.assertEquals(0, [SELECT COUNT() FROM ContentVersion], '0 ContentVersions should exist');
    }
    
    static testMethod void saveFiles_Positive_Test(){
        Identity__c i = [SELECT Id FROM Identity__c WHERE SSN__c = '12345678'];
        
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion], '0 ContentVersions should exist');
        
        Test.startTest();
        IdentityService.FileWrapper fw = new IdentityService.FileWrapper();
        fw.parentId = i.Id;
        fw.fileName = 'Test File';
        fw.data = 'Test Data';
        
        String fileWrapperListJSON = '[' + JSON.serialize(fw) + ']';
        IdentityService.saveFiles(fileWrapperListJSON);
        Test.stopTest();
        
		System.assertEquals(1, [SELECT COUNT() FROM ContentVersion], '1 ContentVersion should have created');
    }
    
    static testMethod void queryIdentityByGeneratedId_Negative_Test(){
        Test.startTest();
        try{
            IdentityService.queryIdentityByGeneratedId(null);
        }
        catch(AuraHandledException ahe){
            System.assertEquals('generatedId can\'t be null', ahe.getMessage(), 'AuraHandledException should have been caught');
        }
        Test.stopTest();
    }
    
    static testMethod void queryIdentityByGeneratedId_Positive_Test(){
        Identity__c i = [SELECT Id, Generated_ID__c FROM Identity__c WHERE SSN__c = '12345678'];
        
        Test.startTest();
        Identity__c i2 = IdentityService.queryIdentityByGeneratedId(i.Generated_ID__c);
        Test.stopTest();
        
        System.assertEquals(i2.Id, i.Id, 'Ids should be the same');
    }
    
    static testMethod void queryContentVersions_Negative_Test(){
        Test.startTest();
        try{
            IdentityService.queryContentVersions(null);
        }
        catch(AuraHandledException ahe){
            System.assertEquals('identityId can\'t be null', ahe.getMessage(), 'AuraHandledException should have been caught');
        }
        Test.stopTest();
    }
    
    static testMethod void queryContentVersions_Positive_Test(){
        Identity__c i = [SELECT Id FROM Identity__c WHERE SSN__c = '12345678'];
        
        Test.startTest();
        List<ContentVersion> cvList = IdentityService.queryContentVersions(i.Id);
        System.assertEquals(0, cvList.size(), '0 ContentVersions should exist');
        
        IdentityService.FileWrapper fw = new IdentityService.FileWrapper();
        fw.parentId = i.Id;
        fw.fileName = 'Test File';
        fw.data = 'Test Data';
        
        String fileWrapperListJSON = '[' + JSON.serialize(fw) + ']';
        IdentityService.saveFiles(fileWrapperListJSON);
        
        cvList = IdentityService.queryContentVersions(i.Id);
        System.assertEquals(1, cvList.size(), '1 ContentVersion should exist');
        Test.stopTest();
    }
    
    static testMethod void queryIdentityById_Negative_Test(){
        Test.startTest();
        try{
            IdentityService.queryIdentityById(null);
        }
        catch(AuraHandledException ahe){
            System.assertEquals('identityId can\'t be null', ahe.getMessage(), 'AuraHandledException should have been caught');
        }
        Test.stopTest();
    }
    
    static testMethod void queryIdentityById_Positive_Test(){
        Identity__c i = [SELECT Id FROM Identity__c WHERE SSN__c = '12345678'];
        
        Test.startTest();
        Identity__c i2 = IdentityService.queryIdentityById(i.Id);
        Test.stopTest();
        
        System.assertEquals(i2.Id, i.Id, 'Ids should be the same');
    }
    
    static testMethod void sendGeneratedIDEmail_Negative_Test(){
        Test.startTest();
        System.assertEquals(0, Limits.getEmailInvocations(), '0 emails should have sent');
        
        IdentityService.sendGeneratedIDEmail(null, null);
        
        System.assertEquals(0, Limits.getEmailInvocations(), '0 emails should have sent');

        try{        
            IdentityService.sendGeneratedIDEmail('test@test', '123456');
        }
        catch(AuraHandledException ahe){
            System.assertEquals(
                'IdentityService.sendGeneratedIDEmail() Error: SendEmail failed. First exception on row 0; '
                + 'first error: INVALID_EMAIL_ADDRESS, Email address is invalid: test@test: [toAddresses, test@test]',
                ahe.getMessage(),
                'AuraHandledException should have been caught'
            );
        }
        Test.stopTest();
    }
    
    static testMethod void sendGeneratedIDEmail_Positive_Test(){
        Identity__c i = [SELECT Email_Address__c, Generated_ID__c FROM Identity__c WHERE SSN__c = '12345678'];
        
        Test.startTest();
        System.assertEquals(0, Limits.getEmailInvocations(), '0 emails should have sent');
        
        IdentityService.sendGeneratedIDEmail(i.Email_Address__c, i.Generated_ID__c);
        
        System.assertEquals(1, Limits.getEmailInvocations(), '1 email should have sent');
        Test.stopTest();
    }
    
    static testMethod void validateAndReturnQualifiedIdentities_Negetive_Test(){
        Identity__c i = [SELECT Id, Date_of_Birth__c, Social_Security_Number__c FROM Identity__c WHERE SSN__c = '12345678'];
        List<Identity__c> identityList = new List<Identity__c>{i};
        
        Test.startTest();
        System.assertEquals(0, IdentityService.validateAndReturnQualifiedIdentities(new List<Identity__c>()).size(), '0 qualified Identity records should have returned');
        
        try{
            IdentityService.validateAndReturnQualifiedIdentities(identityList);
        }
        catch(Exception e){
            System.assertEquals('A record already exists with this Social Security Number', e.getMessage(), 'Exception should have been caught');
        }
        
        i.Social_Security_Number__c = '11111111';
        i.Date_of_Birth__c = Date.today().addDays(1);
        
        try{
            IdentityService.validateAndReturnQualifiedIdentities(identityList);
        }
        catch(Exception e){
            System.assertEquals('Date of Birth cannot be greater than today', e.getMessage(), 'Exception should have been caught');
        }
        Test.stopTest();
    }
    
    static testMethod void validateAndReturnQualifiedIdentities_Positive_Test(){
        Identity__c i = createIdentity(false);
        i.Social_Security_Number__c = '123456789';
        
        Test.startTest();
        List<Identity__c> identityList = IdentityService.validateAndReturnQualifiedIdentities(new List<Identity__c>{i});
        
        System.assertEquals(1, identityList.size(), '1 qualified Identity record should have returned');
        System.assertEquals(i.Id, identityList.get(0).Id, 'Ids should be the same');
        Test.stopTest();
    }
    
    static testMethod void generateId_Positive_Test(){
        Identity__c i = [SELECT Id, Generated_ID__c, Social_Security_Number__c FROM Identity__c WHERE SSN__c = '12345678'];
        i.Social_Security_Number__c = '11111';
        
        String originalGeneratedID = i.Generated_ID__c;
        
        Test.startTest();
        IdentityService.generateId(new List<Identity__c>{i});
        
        System.assertEquals('11111', i.SSN__c, 'SSN__c should have been replaced with new value of Social_Security_Number__c');
        System.assertNotEquals(originalGeneratedID, i.Generated_ID__c, 'New value of Generated_ID__c should be different from the original value');
        Test.stopTest();
    }
    
    static testMethod void sendSecurityVerificationEmails_Negative_Test(){
        Identity__c i = [SELECT Id, Email_Address__c, First_Name__c FROM Identity__c WHERE SSN__c = '12345678'];
        
        List<Identity__c> identityList = new List<Identity__c>();
        
        Test.startTest();
        System.assertEquals(0, Limits.getEmailInvocations(), '0 emails should have sent');
        
        IdentityService.sendSecurityVerificationEmails(identityList);
                
        System.assertEquals(0, Limits.getEmailInvocations(), '0 emails should have sent');
        
        i.Email_Address__c = 'test@test';
        identityList.add(i);
        
        try{
            IdentityService.sendSecurityVerificationEmails(identityList);
        }
        catch(AuraHandledException ahe){
            System.assertEquals(
                'IdentityService.sendSecurityVerificationEmails() Error: SendEmail failed. First exception on row 0; first error: '
                + 'INVALID_EMAIL_ADDRESS, Email address is invalid: test@test: [toAddresses, test@test]',
                ahe.getMessage(),
                'AuraHandledException should have been caught'
            );
        }
        Test.stopTest();
    }
    
    static testMethod void sendSecurityVerificationEmails_Positive_Test(){
        Identity__c i = [SELECT Id, Email_Address__c, First_Name__c FROM Identity__c WHERE SSN__c = '12345678'];
        
        Test.startTest();
        System.assertEquals(0, Limits.getEmailInvocations(), '0 emails should have sent');
        
        IdentityService.sendSecurityVerificationEmails(new List<Identity__c>{i});
        
        System.assertEquals(1, Limits.getEmailInvocations(), '1 email should have sent');
        Test.stopTest();
    }
    
    static testMethod void queryIdentities_Negative_Test(){
        Test.startTest();
        try{
            IdentityService.queryIdentities(new List<String>{'Test__c'}, null);
        }
        catch(AuraHandledException ahe){
            System.assertEquals(
                'IdentityService.queryIdentities() Error: No such column \'Test__c\' on entity \'Identity__c\'. '
                + 'If you are attempting to use a custom field, be sure to append the \'__c\' after the custom field name. '
                + 'Please reference your WSDL or the describe call for the appropriate names.',
                ahe.getMessage(),
                'AuraHandledException should have been caught'
            );
        }
        Test.stopTest();
    }
    
    static testMethod void queryIdentities_Positive_Test(){
        Test.startTest();
        System.assertEquals(
            1,
            IdentityService.queryIdentities(new List<String>{'Id', 'First_Name__c', 'Last_Name__c'}, 'WHERE SSN__c = \'12345678\'').size(),
            '1 Identity__c record should have returned'
        );
        Test.stopTest();
    }
    
    static testMethod void throwAureHandledException_Negative_Test(){
        Test.startTest();
		IdentityService.throwAureHandledException(null);        
        Test.stopTest();
    }
    
    static testMethod void throwAureHandledException_Positive_Test(){
        Test.startTest();
        try{
            IdentityService.throwAureHandledException('Test Error');
        }
        catch(AuraHandledException ahe){
            System.assertEquals(
                'Test Error',
                ahe.getMessage(),
                'AuraHandledException should have been caught'
            );
        }
        Test.stopTest();
    }
    
    private static Identity__c createIdentity(Boolean doInsert){
        Identity__c i = new Identity__c();
        i.First_Name__c = 'FirstName';
        i.Last_Name__c = 'LastName';
        i.Date_of_Birth__c = Date.today();
        i.Form_Identification_Number__c = '12345678';
        i.Social_Security_Number__c = '12345678';
        i.Email_Address__c = 'test@test.com';
        i.Security_Question__c = 'Test?';
        i.Security_Answer__c = 'Test';
        
        if(doInsert){
        	insert i;
        }
        
        return i;
    }
    
}