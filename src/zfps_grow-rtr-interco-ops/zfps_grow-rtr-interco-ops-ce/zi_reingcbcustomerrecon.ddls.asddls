// Projection over the released API I_CustomerCompany with the authorization
// check switched off.
//
// Why: ZCL_REING_CONTAB_DOC~set_context reads the reconciliation account of the
// intercompany partner from inside lsc_zi_reingcarun~save_modified. The BDEF of
// ZI_REINGCARUN declares strict ( 2 ), and no authorization check is allowed in
// the RAP save phase: reading I_CustomerCompany directly raises an implicit
// AUTHORITY-CHECK(DCL) and the kernel dumps with BEHAVIOR_ILLEGAL_STATEMENT
// (ST22 key BEHAVIOR_ILLEGAL_STATEMENT_20260909_160023, TS4-400).
//
// Why it is safe: the reconciliation account of an IC partner is accounting
// configuration, not user-scoped data, and the right to run Simulate/Post/Storno
// is already enforced by the business object. Keeping the DCL would also be
// functionally wrong here -- the CA operator holds no FI roles (F_KNA1_BUK), so
// the SELECT would silently return an empty account.
//
// Same pattern as ZI_IntercoCompanyCode and ZC_IntercoRelationship, the other two
// CDS views read by that method.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONTAB - Cta reconciliacion cliente IC'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ReingCbCustomerRecon
  as select from I_CustomerCompany
{
  key Customer,
  key CompanyCode,
      ReconciliationAccount
}
