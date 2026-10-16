@EndUserText.label: 'Document Flow Herarchy'
define abstract entity ZR_IntercoDocChildFlow
  //  with parameters parameter_name : parameter_type
{
  key id                 : uuid;
  key documenttype       : int4;
  key documentkey        : abp_creation_user;
      DocumentName       : zint_dte_cat_name;
      parentdocumenttype : int4;
      parentdocumentkey  : abp_creation_user;
      ParentDocumentName : zint_dte_cat_name;
      category_id        : int4;
//      CategoryName       : zint_dte_cat_name;
      isadjustment       : abap_boolean;
      status             : zint_dte_cpid_status;
      createdby          : abp_creation_user;
      createdat          : abp_creation_tstmpl;
      _Parent            : association to parent ZR_INTERCODOCParentFLOW;

}
