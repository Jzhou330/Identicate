import { LightningElement, api, track } from 'lwc';
import queryIdentityById from '@salesforce/apex/IdentityService.queryIdentityById';
import sendGeneratedIDEmail from '@salesforce/apex/IdentityService.sendGeneratedIDEmail';

export default class IdSecurityVerification extends LightningElement {

    @api identityId;
    @track identity;
    @track securityQuestion;
    @track inputAnswer;
    @track errorMessage;
    @track success = false;
    
    /** 
     * Handles initial data set up
     * Called immediately after page loads
     * Calls queryIdentityById() Apex method to query for the Identity__c record by Id
     * 
     * @return None
     **/
    connectedCallback(){
        queryIdentityById({identityId : this.identityId}).then(response => {
            this.identity = response;
            this.securityQuestion = this.identity.Security_Question__c;
        }).catch(error => {
            console.error(error.body.message);
        });
    }

    /** 
     * Handles submit event
     * Called on an onclick event of a lightning-button
     * Calls sendGeneratedIDEmail() Apex method to send email
     * 
     * @return None
     **/
    handleSubmit(){
        this.errorMessage = "";
        this.inputAnswer = this.template.querySelector('lightning-input').value;

        if(!this.inputAnswer || this.inputAnswer !== this.identity.Security_Answer__c){
            this.errorMessage = "Security Answer is blank or incorrect. Please try again.";
            return;
        }

        sendGeneratedIDEmail({toAddress : this.identity.Email_Address__c, generatedID : this.identity.Generated_ID__c}).then(response => {
            console.log('response = ' + response)
        }).catch(error => {
            console.error(error.body.message);
        });

        this.success = true;
    }

}