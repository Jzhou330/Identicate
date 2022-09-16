/*************************************************************************************************************
 * @name            IdentityTrigger
 * @author          Jeffrey Zhou
 * @created         09 / 15 / 2022
 * @description     Trigger for Identity__c
**************************************************************************************************************/
trigger IdentityTrigger on Identity__c(before insert, after insert){
	
    if(Trigger.isInsert){
        if(Trigger.isBefore){
            List<Identity__c> filteredIdentities = IdentityService.validateAndReturnQualifiedIdentities(Trigger.new);
            IdentityService.generateId(filteredIdentities);
        }
        
        if(Trigger.isAfter){
            IdentityService.sendSecurityVerificationEmails(Trigger.new);
        }
    }
    
}