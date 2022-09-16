import { LightningElement, track} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import saveFiles from '@salesforce/apex/IdentityService.saveFiles';
import queryIdentityByGeneratedId from '@salesforce/apex/IdentityService.queryIdentityByGeneratedId';
import queryContentVersions from '@salesforce/apex/IdentityService.queryContentVersions';

export default class IdGenerator extends NavigationMixin(LightningElement){
    @track identity;
    @track identityId;
    @track generatedId;
    @track imgURLs = [];
    @track alreadyGeneratedId = false;
    @track attachmentsCount = 0;
    @track errorMessage;
    @track files = [];
    BASE64EXP = new RegExp(/^data(.*)base64,/);

    /** 
     * Handles file upload event
     * Called on an onclick event of a lighting-input
     * 
     * @return None
     **/
    handleUpload(){
        this.attachmentsCount = 0;
    }

    /** 
     * Handles file upload change event
     * Called on an onchange event of a lighting-input
     * 
     * @param event - The event object
     * @return None
     **/
    async handleUploadOnChange(event){
        this.files = await Promise.all(
            [...event.target.files].map(file => this.readFile(file))
        );
        
        this.attachmentsCount = this.files.length;
    }

    /** 
     * Reads file object
     * 
     * @param file - The file object to read
     * @return None
     **/
    readFile(file) {
        return new Promise((resolve, reject) => {
            const fileReader = new FileReader();
            fileReader.onerror = () => reject(fileReader.error);
            fileReader.onload = () => resolve(
                this.createFileWrapper(file, fileReader)
            );
            fileReader.readAsDataURL(file);
        });
    }

    /** 
     * Creates FileWrapper objects and returns them
     * 
     * @param file - The file object to read
     * @return FileWrapper object
     **/
    createFileWrapper(file, fileReader){
        var fileWrapper = {};
        fileWrapper.fileName = file.name;
        fileWrapper.data = fileReader.result.replace(this.BASE64EXP, "");
        return fileWrapper;
    }

    /** 
     * Handles success event after the Identity__c record has been inserted
     * Calls saveFiles() Apex method to insert ContentVersions
     * Called on an onsuccess event of a lightning-record-edit-form
     * 
     * @param event - The event object
     * @return None
     **/
    handleSuccess(event){
        var identityId = event.detail.id;
        this.generatedId = event.detail.fields.Generated_ID__c.value;

        if(this.files && identityId){
            for(var f of this.files){
                f.parentId = identityId;
            }

            saveFiles({fileWrapperListJSON : JSON.stringify(this.files)}).then(response => {
                console.log("response = " + response);
            }).catch(error => {
                console.error(error.body.message);
            });
        }
    }

    /** 
     * Handles error event after the Identity__c record has been inserted
     * Called on an onerror event of a lightning-record-edit-form
     * 
     * @param event - The event object
     * @return None
     **/
    handleError(event){
        this.errorMessage = event.detail.detail;
    }

    /** 
     * Handles exit of the form event
     * Redirects to the Identity__c home page
     * Called on an onclick event of multiple places
     * 
     * @return None
     **/
    handleExit(){
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Identity__c',
                actionName: 'home',
            }
        });
    }

    /** 
     * Handles create Identity__c record submit event
     * Called on an onclick event of a lightning-button
     * Clears error message
     * 
     * @return None
     **/
    handleCreateIdentitySubmit(){
        this.errorMessage = null;
    }

    /** 
     * Handles already generated ID event
     * Called on an onclick event of an "a" tag
     * 
     * @param event - The event object
     * @return None
     **/
    handleAlreadyGeneratedID(event){
        this.generatedId = event.target.value;
        this.alreadyGeneratedId = true;
    }

    /** 
     * Handles generated ID submit event
     * Called on an onclick event of a lightning-button
     * Calls queryIdentityByGeneratedId() Apex method to query for the Identity__c record by generated ID
     * Calls queryContentVersions() Apex method to query for ContentVersions related to the Identity__c record
     * 
     * @return None
     **/
    handleEnterGeneratedIDSubmit(){
        this.generatedId = this.template.querySelector("lightning-input[data-id=enterGeneratedID]").value;

        if(!this.generatedId){
            return;
        }

        queryIdentityByGeneratedId({generatedId : this.generatedId}).then(response => {
            this.identity = response;
            if(this.identity){
                this.identityId = this.identity.Id;

                if(this.identityId){
                    queryContentVersions({identityId : this.identityId}).then(response => {
                        for(var cv of response){
                            this.imgURLs.push('/sfc/servlet.shepherd/version/download/' + cv.Id);
                        }
                    }).catch(error => {
                        console.error(error.body.message);
                    });
                }
            }
        }).catch(error => {
            console.error(error.body.message);
        });
    }

    /** 
     * Handles retry event
     * Called on an onclick event of a lightning-button 
     * 
     * @return None
     **/
    handleRetry(){
        this.generatedId = null;
    }
}