// Projection over the released API I_SupplierCompany with the authorization
// check switched off. AP counterpart of ZI_ReingCbCustomerRecon -- see that view
// for the full rationale.
//
// Short version: ZCL_REING_CONTAB_DOC~set_context runs in the RAP save phase of
// ZI_REINGCARUN (strict ( 2 )), where no authorization check is allowed, so a
// direct read of I_SupplierCompany dumps with BEHAVIOR_ILLEGAL_STATEMENT.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONTAB - Cta reconciliacion proveedor IC'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ReingCbSupplierRecon
  as select from I_SupplierCompany
{
  key Supplier,
  key CompanyCode,
      ReconciliationAccount
}
