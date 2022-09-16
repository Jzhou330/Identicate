/*************************************************************************************************************
 * @name            IdentityService
 * @author          Jeffrey Zhou
 * @created         09 / 15 / 2022
 * @description     Service Class for Identity__c
**************************************************************************************************************/
public without sharing class IdentityService{
    
    /**
     * idGenerator lWC methods 
     **/
    
    /** 
     * Receives a JSON String comprised of a List of FileWrappers and inserts new ContentVersions
     * 
     * @param String fileWrapperListJSON - JSON String of a List of FileWrappers
     * @return None
     **/
	@AuraEnabled    
    public static void saveFiles(String fileWrapperListJSON){
        if(fileWrapperListJSON == null){
            throwAureHandledException('fileWrapperListJSON can\'t be null');
        }
        
		List<FileWrapper> fileWrapperList = (List<FileWrapper>)JSON.deserialize(fileWrapperListJSON, List<FileWrapper>.class);
        List<ContentVersion> cvList = new List<ContentVersion>();
        Id userId = UserInfo.getUserId();
        for(FileWrapper fw : fileWrapperList){
            ContentVersion cv = new ContentVersion();
            cv.Title = fw.fileName;
            cv.Origin = 'C';
            cv.ContentLocation = 'S';
            cv.PathOnClient = '/' + fw.fileName;
            cv.OwnerId = userId;
            cv.FirstPublishLocationId = fw.parentId;
            cv.VersionData = EncodingUtil.base64Decode(fw.data);
            cvList.add(cv);
        }
        
        try{
            insert cvList;
        }
        catch(DMLException de){
            throwAureHandledException('IdentityService.saveFiles() - ContentVersion insert - Error: ' + de.getMessage());
        }
    }
    
    /** 
     * Queries for an Identity__c record by Generated_ID__c
     * 
     * @param String generatedId - The Generated_ID__c to query by
     * @return Identity__c record
     **/
    @AuraEnabled 
    public static Identity__c queryIdentityByGeneratedId(String generatedId){
        if(String.isBlank(generatedId)){
            throwAureHandledException('generatedId can\'t be null');
        }
        
        List<Identity__c> identityList = queryIdentities(null, 'WHERE Generated_ID__c = \'' + generatedId + '\'');
        return !identityList.isEmpty() ? identityList.get(0) : null;
    }

    /** 
     * Queries for ContentVersion records by Identity__c Id
     * 
     * @param Id identityId - The Identity__c Id to query by
     * @return List<ContentVersion>
     **/    
    @AuraEnabled
    public static List<ContentVersion> queryContentVersions(Id identityId){
        if(identityId == null){
            throwAureHandledException('identityId can\'t be null');
        }
        
        return new List<ContentVersion>([SELECT Id FROM ContentVersion WHERE FirstPublishLocationId = :identityId]);
    }
    
    /**
     * idSecurityVerification lWC methods 
     **/
    
    /** 
     * Queries for an Identity__c record by Id
     * 
     * @param Id identityId - The Id to query by
     * @return Identity__c record
     **/
    @AuraEnabled 
    public static Identity__c queryIdentityById(Id identityId){
        if(identityId == null){
            throwAureHandledException('identityId can\'t be null');
        }
        
        List<Identity__c> identityList = queryIdentities(
            new List<String>{'Id', 'Email_Address__c', 'Generated_ID__c', 'Security_Answer__c', 'Security_Question__c'},
            'WHERE Id = \'' + identityId + '\''
        );
        return !identityList.isEmpty() ? identityList.get(0) : null;
    }
    
    /** 
     * Sends emails to notify the user generated ID printed out and QR Code which contains the generated ID
     * 
     * @param String toAddress - The email address to send the email to
     * @param String generatedID - The generated ID to include in the email
     * @return None
     **/ 
    @AuraEnabled
    public static void sendGeneratedIDEmail(String toAddress, String generatedID){
        if(String.isBlank(toAddress) || String.isBlank(generatedID)){
            return;
        }
        
        Messaging.SingleEmailMessage email = createSingeEmailMessage(
            'Generated ID',
            toAddress,
            'This is your unique generated ID and the corresponding QR code: '
            + generatedID
            + '<br/><br/><img src="https://chart.googleapis.com/chart?chs=250x250&cht=qr&chl='
            + generatedID
            + '"><br/><br/>Please use QR code at acceptable destinations with Okta Verify.<br/><br/>Thank you'
        );
        
        try{
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
        }
        catch(EmailException ee){
            throwAureHandledException('IdentityService.sendGeneratedIDEmail() Error: ' + ee.getMessage());
        }
        
    }
    
    /**
     * IdentityTrigger methods 
     **/
    
    /** 
     * Validates and returns qualified Identity__c records
     * 
     * @param List<Identity__c> identityList - The list of Identity__c records
     * @return List<Identity__c>
     **/ 
    public static List<Identity__c> validateAndReturnQualifiedIdentities(List<Identity__c> identityList){
        List<Identity__c> qualifiedIdentityList = new List<Identity__c>();
        
        if(identityList.isEmpty()){
            return qualifiedIdentityList;
        }
        
        Set<String> newSSNSet = new Set<String>();
        for(Identity__c i : identityList){
            newSSNSet.add(i.Social_Security_Number__c);
        }

		Set<String> existingSSNSet = new Set<String>();
        for(Identity__c i : [SELECT Id, Social_Security_Number__c FROM Identity__c WHERE SSN__c IN :newSSNSet]){
            existingSSNSet.add(i.Social_Security_Number__c);
        }
        
        Date todayDate = Date.today();
        for(Identity__c i : identityList){
            if(i.Date_of_Birth__c > todayDate){
                i.addError('Date of Birth cannot be greater than today');
                continue;
            }
            
            if(existingSSNSet.contains(i.Social_Security_Number__c)){
                i.addError('A record already exists with this Social Security Number');
                continue;
            }
            
            qualifiedIdentityList.add(i);
        }
        
        return qualifiedIdentityList;
    }
    
    /** 
     * Generates IDs for the Identity__c records
     * 
     * @param List<Identity__c> identityList - The list of Identity__c records
     * @return None
     **/ 
    public static void generateId(List<Identity__c> identityList){
        for(Identity__c i : identityList){
            i.Generated_ID__c = EncodingUtil.ConvertTohex(Crypto.GenerateAESKey(256));
            i.SSN__c = i.Social_Security_Number__c;
        }
    }
    
    /** 
     * Sends security verification emails
     * 
     * @param List<Identity__c> identityList - The list of Identity__c records
     * @return None
     **/ 
    public static void sendSecurityVerificationEmails(List<Identity__c> identityList){
        if(identityList.isEmpty()){
            return;
        }
        
        List<Messaging.SingleEmailMessage> emailsList = new List<Messaging.SingleEmailMessage>();
        for(Identity__c i : identityList){
            emailsList.add(
                createSingeEmailMessage(
                    'Security Verification',
                    i.Email_Address__c,
                    'Hi ' + i.First_Name__c + ',<br/><br/>Please visit the link below and answer the security question. '
                    + 'Once successfully answered, another email will be sent to you with the generated ID.<br/><br/>'
                    + '<a href="https://okta-a1-dev-ed.my.salesforce-sites.com/IDSecurityVerificationPage?id=&quot;'
                    + i.Id
                    + '&quot;">Answer Security Question</a><br/><br/>Thank you'
                )
            );
        }
        
        try{
        	Messaging.sendEmail(emailsList);
        }
        catch(EmailException  ee){
            throwAureHandledException('IdentityService.sendSecurityVerificationEmails() Error: ' + ee.getMessage());
        }
        
    }
    
    /**
     * Helper methods 
     **/
    
    /** 
     * Queries and returns Identity__c records
     * 
     * @param List<String> fieldsList - The list of fields to query
     * @param String whereClause - The where clause of the query
     * @return List<Identity__c>
     **/
    @TestVisible
    private static List<Identity__c> queryIdentities(List<String> fieldsList, String whereClause){
        String query = 'SELECT ';
        
        if(fieldsList == null || fieldsList.isEmpty()){
            query += 'Id';
        }
        else{
            query += String.join(fieldsList, ', ');
        }
        
        query += ' FROM Identity__c';
        
        if(!String.isBlank(whereClause)){
            query += ' ' + whereClause;
        }
        
        List<Identity__c> identitiesList = new List<Identity__c>();
        try{
            identitiesList = Database.query(query);
        }
        catch(QueryException qe){
            throwAureHandledException('IdentityService.queryIdentities() Error: ' + qe.getMessage());
        }
        
        return identitiesList;
    }
    
    /** 
     * Creates a Messaging.SingleEmailMessage instance and returns it
     * 
     * @param String subject - The email subject
     * @param String toAddress - The email address to send the email to
     * @parm String htmlBody - The htmlBody of the email
     * @return Messaging.SingleEmailMessage
     **/
    private static Messaging.SingleEmailMessage createSingeEmailMessage(String subject, String toAddress, String htmlBody){
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject(subject);
        email.setOrgWideEmailAddressId(oweaId);
        email.setToAddresses(new List<String>{toAddress});
        email.setHtmlBody(htmlBOdy);
        return email;
    }
    
    /** 
     * Throws AuraHandledException
     * 
     * @param String error - The error message to throw
     * @return None
     **/
    @TestVisible
    private static void throwAureHandledException(String error){
        if(String.isBlank(error)){
            return;
        }
        
        AuraHandledException ahe = new AuraHandledException(error);
        ahe.setMessage(error);
        throw ahe;
    }
    
    /** 
     * OrgWideEmailAddress Id Property
     **/
    private static Id oweaId{
        get{
            if(oweaId == null){
                oweaId = [SELECT Id FROM OrgWideEmailAddress LIMIT 1].Id;
            }
            return oweaId;
        }
        private set;
    }
    
    /** 
     * Wrapper Class to represent the File objects
     **/
    @TestVisible
    private class FileWrapper{
        public Id parentId;
        public String fileName;
		public String data;        
    }
    
}