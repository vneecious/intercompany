@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Identificador genova'
define view entity ZI_Interco_Split_CEBE
  as select distinct from ZI_IntercoProposalItemOrGLAcct as Source
    inner join            ZI_IntercoProposal             as Header      on Source.Id = Header.Id
    inner join            ZI_TVARVC                      as VarProvider on  VarProvider.Name = 'Z_GENOVA_PROVIDER'
                                                                        and VarProvider.Low  = Header.ProviderCompanyCode
    inner join            ZI_TVARVC                      as VarProduct  on  VarProduct.Name = 'Z_GENOVA_PRODUCT'
                                                                        and VarProduct.Low  = Header.Product
    inner join            ZI_TVARVC                      as VarHier     on  VarHier.Name = 'Z_GENOVA_HIER'
                                                                        and VarHier.Low  = Source.CostCenterStdHierArea
{
  key Source.Id,
  key Source.ItemId,
  key Source.CostCenterStdHierArea
}
where
  Source.cebe_aux = '200'
