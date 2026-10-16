@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Identificador genova'
define view entity ZI_INTERCO_SPLIT_CEBE_MLA
  as select distinct from zfi_a_intrc_cpig   as Source
    inner join            ZI_IntercoProposal as Header      on Source.id = Header.Id
    inner join            ZI_TVARVC          as VarProvider on  VarProvider.Name = 'Z_GENOVA_PROVIDER'
                                                            and VarProvider.Low  = Header.ProviderCompanyCode
    inner join            ZI_TVARVC          as VarProduct  on  VarProduct.Name = 'Z_GENOVA_PRODUCT'
                                                            and VarProduct.Low  = Header.Product
  //    inner join            ZI_TVARVC                      as VarHier     on  VarHier.Name = 'Z_GENOVA_HIER'
  //                                                                        and VarHier.Low  = Source.CostCenterStdHierArea
{
  key Source.id,
  key Source.item_id
      //  key Source.CostCenterStdHierArea
}
where
  -- Solo aplicar lógica Génova si el centro de costo
  -- del registro original termina en 200
  right(Source.cost_center, 3) = '200'
