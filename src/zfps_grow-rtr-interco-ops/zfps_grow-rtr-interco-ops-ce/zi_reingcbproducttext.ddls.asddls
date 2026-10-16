// Projection over the released API I_ProductDescription with the authorization
// check switched off. Change ID V007 (16.09.2026 | EXT_GONZALCA), bug #73 (d1).
//
// Why it exists: ZCL_REING_CONTAB_DOC~get_maktx_cleaned derives the intercompany
// concept that travels in BSEG-ZUONR from the material description
// (ET-REING-CONTAB-001 v41 SS8.19). The spec writes that read as a SELECT on
// MAKT, but this package is ABAP for Cloud Development and the activation is
// rejected with "El uso de Tabla MAKT no esta permitido": MAKT is not a
// released API. I_ProductDescription is the released (C1) replacement.
//
// Why the projection and not the I_* view directly: I_ProductDescription is
// @AccessControl.authorizationCheck: #CHECK, and set_context -- where this read
// lives -- is the very method whose DCL reads dumped the LUW with
// BEHAVIOR_ILLEGAL_STATEMENT once CONTAB ran inside the RAP save phase
// (ST22 key BEHAVIOR_ILLEGAL_STATEMENT_20260909_160023, TS4-400). CONTAB was
// moved out of RAP on 14.09.2026, but the warning in that method still holds:
// "Do NOT point these SELECTs back at the I_* views".
//
// Why it is safe: a material description is master data, not user-scoped data,
// and the right to run Simulate/Post/Storno is already enforced by the business
// object. Keeping the DCL would also be functionally wrong here -- the CA
// operator holds no material-master roles, so the SELECT would silently return
// an empty description and the concept would fall back to the bare material
// number, which is not a valid entry of set ZFI_INTERCO_CONCEPTOS.
//
// Same pattern as ZI_ReingCbCustomerRecon and ZI_ReingCbSupplierRecon.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONTAB - Descripcion de material'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ReingCbProductText
  as select from I_ProductDescription
{
  key Product,
  key Language,
      ProductDescription
}
