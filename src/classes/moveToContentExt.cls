/**
 * 
 * Extension for a Standard Controller (for any object) 
 * that displays a list of all attachments to that record, 
 * and then allows the user to select which attachment to 
 * add to Salesforce CRM Content.
 *
 * Scott VonSchilling
 * Salesforce Developer, Internet Creations
 * @Scott_VS
 *
 */
 
 
public with sharing class moveToContentExt {
    
    public List<attachmentClass> myAttachments {get;set;}
    public String selectedLibrary {get; set;}
    public Boolean selectAll {get;set;}
    private ApexPages.StandardController cntrl;

    //Constructor
    public moveToContentExt(ApexPages.StandardController controller) {
        // initialize variables
        this.cntrl = controller;
        this.selectedLibrary = '';
        this.selectAll = false;
        
        // load attachments
        this.myAttachments = new List<attachmentClass>();
        for (Attachment a : [SELECT Name, Description FROM Attachment WHERE ParentId =: this.cntrl.getId()])
            this.myAttachments.add(new AttachmentClass(a)); 
        
    }
    
    // Encapsulate an attachment with a checkbox for selection.
    public class attachmentClass{
        public boolean selected {get;set;}
        public Attachment attch {get;set;}
        
        public attachmentClass(Attachment a){
            this.attch = a;
            this.selected = false;
        }
    }
    
   // Populate a list of Libraries for picklist.
   public List<SelectOption> getLibraries() {
        List<SelectOption> options = new List<SelectOption>();
        
        options.add(new SelectOption('','My Personal Library'));
        for (ContentWorkspace library : [SELECT id, name FROM ContentWorkspace])
            options.add(new SelectOption(library.id,library.name));

        return options;
    }
    
    // add selected attachemnts to Salesforce CRM Content
    public PageReference addToLibrary(){
        // Gather list of selected attachments
        List<Attachment> selectedAttachments = new List<Attachment>();
        List<Id> selectedIds = new List<Id>();
        for (AttachmentClass a : this.myAttachments){
            if (a.selected){
                selectedAttachments.add(a.attch);
                selectedIds.add(a.attch.id);
            }
         }
        
        // Get the data for each Attachment
        Map<id, Attachment> attachmentBodies = new Map<Id, Attachment>( [SELECT Body FROM Attachment WHERE ParentId =: this.cntrl.getId()]);
        
        // Create and insert new CRM docs
        List <ContentVersion> newFiles = new List<ContentVersion>();
        for (Attachment a : selectedAttachments){
            ContentVersion newFile = new ContentVersion();
            newFile.Title = a.Name;
            newFile.pathOnClient ='/' + a.Name;
            newFile.Description = a.Description;
            newFile.VersionData = attachmentBodies.get(a.id).Body;
            newFiles.add(newFile);
        }
        insert newFiles;
        
        // Get the ContendDocumentId created from the version files just inserted
        List<id> newVersionIds = new List<id>();
        for (ContentVersion newFile : newFiles)
            newVersionIds.add(newFile.id);
        newFiles = [SELECT ContentDocumentId FROM ContentVersion WHERE id = : newVersionIds];
        
        
        // Link the new documents to Library user selected from picklist
        List<ContentWorkspaceDoc> libraryDocs = new List<ContentWorkspaceDoc>();
        if (this.selectedLibrary != null && this.selectedLibrary != '')
            for (ContentVersion newFile : newFiles)
                libraryDocs.add(new ContentWorkspaceDoc(ContentDocumentId = newFile.ContentDocumentId, ContentWorkspaceId = this.selectedLibrary));
        insert libraryDocs;
        
        // return back to record
        return this.cntrl.cancel();
    }
    
    // Select or Unselect all Attachments on list
    public PageReference selectAllClick(){
        for (AttachmentClass a : this.myAttachments)
            a.selected = this.selectAll;
        return null;
    }
    
    
    // Unit Test
    @IsTest
    public static void moveToContentExt() {
        // Create Case
        Case testCase = new Case();
        insert testCase;
        
        // Create File
        String fileName = 'Test_File_000.txt';
        String fileContent = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.';
        
        Attachment testAttachment = new Attachment();
        testAttachment.name = fileName;
        testAttachment.body = Blob.valueOf(fileContent);
        testAttachment.parentId = testCase.id;
        
        insert testAttachment;
        
        // Load Extention
        moveToContentExt myExt = new moveToContentExt(new ApexPages.StandardController(testCase));
        
        // Test Libraries 
        List<ContentWorkspace> libraryList = [SELECT id FROM ContentWorkspace];
        List<SelectOption> libraryOptions = myExt.getLibraries();
        System.assertEquals(libraryList.size() + 1, libraryOptions.size());
        System.assertEquals('My Personal Library', libraryOptions[0].getLabel());
        
        // Make sure that testAttachment is on list and is not selected.
        System.assertEquals(1, myExt.myAttachments.size());
        System.assertEquals(false, myExt.selectAll);
        System.assertEquals(false, myExt.myAttachments[0].selected);
        System.assertEquals(fileName, myExt.myAttachments[0].attch.name);
        
        // Select All
        myExt.selectAll = true;
        myExt.selectAllClick();
        System.assertEquals(true, myExt.myAttachments[0].selected);
        
        // Click the "Add To Library" button
        myExt.addToLibrary();
        
        // Make sure that Attachment is now in Content and is in personal library
        ContentVersion testDocument = [SELECT PublishStatus, pathOnClient, VersionData FROM ContentVersion WHERE Title =: fileName];
        System.assertEquals('R', testDocument.PublishStatus);
        System.assertEquals('/'+fileName, testDocument.pathOnClient);
        
        
    }

}