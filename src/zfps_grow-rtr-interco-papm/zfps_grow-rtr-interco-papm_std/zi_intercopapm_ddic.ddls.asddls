@AbapCatalog.sqlViewName: 'ZIV_INTERCOPAPM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS Interco PaPM - DDIC'
@Metadata.ignorePropagatedAnnotations: true
define view ZI_IntercoPaPM_DDIC
  as select distinct from ZI_IntercoProposalItemBaOGlAc
  association to ZI_IntercoProposalItemBasisDet as _ProposalItemBasisDetails on  _ProposalItemBasisDetails.id         = $projection.id
                                                                             and _ProposalItemBasisDetails.item_id    = $projection.item_id
                                                                             and _ProposalItemBasisDetails.GLAccount  = $projection.hkont
                                                                             and _ProposalItemBasisDetails.CostCenter = $projection.kostl
{
  id,
  item_id,
  itembasis_id,
  0                                               as itemcalc_id,
  GlAccount                                       as hkont,
  CostCenter                                      as kostl,
  _Items.ProviderCompanyCode                      as bukrs_prestadora,
  _Items._Proposal.FiscalYear                     as gjahr,
  _Items._Proposal.FiscalPeriod                   as monat,
  _Items.recipientcompanycode                     as bukrs_prestataria,
  _Items._Proposal.Product                        as matnr,
  _Items._Proposal.ProductName                    as maktx,
  _Items._Proposal.Product                        as concepto,
  profitcenter                                    as prctr,
  _Items.ProfitCenterName                         as prctr_name,
  _Items.ProfitCenterName                         as subbu,
  _ProposalItemBasisDetails.Department            as department,
  _ProposalItemBasisDetails.CostCenterStdHierArea as hier_area,
  _ProposalItemBasisDetails.CCAllocation          as allocation,
  GlobalCurrency                                  as gloracctglobcurr,
  AmountInGlobalCurrency                          as total,
  _ProposalItemBasisDetails._PandLFlat.IDL2       as pl,
  AmountInGlobalCurrency
    + markupamount
    + grossingupbaseamount
    + grossingupmarginamount
    + latepaymentinterestamount
    + providergrossingupamount                    as totalconc,
  GlobalCurrency                                  as basisglobalcurr,
  AmountInGlobalCurrency                          as base,
  markupamount                                    as mkup,
  grossingupbaseamount                            as gupb,
  grossingupmarginamount                          as gupk,
  createdby                                       as created_by,
  createdat                                       as created_at
}
