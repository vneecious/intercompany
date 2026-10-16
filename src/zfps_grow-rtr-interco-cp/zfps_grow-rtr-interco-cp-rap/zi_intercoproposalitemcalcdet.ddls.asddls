@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item Details'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemCalcDet
  as select distinct from ZI_IntercoProposalItemBaOGlAc as ProposalItemCalc
    cross join            ZI_IntercoTariffs             as T
  association to ZI_IntercoProposalItem         as _ProposalItem             on  _ProposalItem.Id           = $projection.id
                                                                             and _ProposalItem.Item_Id      = $projection.item_id
                                                                             and _ProposalItem.ItemBasis_Id = $projection.itembasis_id
  association to ZI_IntercoProposalItemBasisDet as _ProposalItemBasisDetails on  _ProposalItemBasisDetails.id         = $projection.id
                                                                             and _ProposalItemBasisDetails.item_id    = $projection.item_id
                                                                             and _ProposalItemBasisDetails.GLAccount  = $projection.GLAccount
                                                                             and _ProposalItemBasisDetails.CostCenter = $projection.CostCenter
  association to ZI_IntercoProposalItemCalc     as _ProposalItemCalc         on  _ProposalItemCalc.id      = $projection.id
                                                                             and _ProposalItemCalc.item_id = $projection.item_id

{
  key    ProposalItemCalc.id,
  key    ProposalItemCalc.item_id,
  key    ProposalItemCalc.itembasis_id,
  key    ProposalItemCalc.GlAccount                    as GLAccount,
  key    ProposalItemCalc.CostCenter                   as CostCenter,
  key    cast( T.TariffType as zint_tariff_type )      as TariffType,
         T.Description                                 as TariffDescription,
         _ProposalItemBasisDetails.Product,
         _ProposalItemBasisDetails.ProfitCenter        as ProfitCenter,
         _ProposalItemBasisDetails.PandLL5ID,
         _ProposalItemBasisDetails.CostCenterStdHierArea,
         _ProposalItemBasisDetails.CCAllocation,
         _ProposalItemBasisDetails.CCConsolidation,
         _ProposalItemBasisDetails.CostCenterD4,
         _ProposalItemBasisDetails.Department,

         case T.TariffType
           when '01' then cast( ProposalItemCalc.markup as abap.decfloat34 )
           when '02' then cast( ProposalItemCalc.grossingupbase as abap.decfloat34 )
           when '03' then cast( ProposalItemCalc.grossingupmargin as abap.decfloat34 )
           when '04' then cast( ProposalItemCalc.latepaymentinterest as abap.decfloat34 )
           when '05' then cast( ProposalItemCalc.providergrossingup as abap.decfloat34 )
           when '06' then cast(100 as abap.decfloat34 )  // 06 is the base amount
         end                                           as TariffRate,

         @Semantics.amount.currencyCode: 'GlobalCurrency'
         case T.TariffType
              when '01' then ProposalItemCalc.markupamount
              when '02' then ProposalItemCalc.grossingupbaseamount
              when '03' then ProposalItemCalc.grossingupmarginamount
              when '04' then ProposalItemCalc.latepaymentinterestamount
              when '05' then ProposalItemCalc.providergrossingupamount
              when '06' then ProposalItemCalc.AmountInGlobalCurrency  // 06 is the base amount
            end                                        as AmountInGlobalCurrency,
         _ProposalItemBasisDetails.GlobalCurrency      as GlobalCurrency,

         @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
         case T.TariffType
              when '01' then ProposalItemCalc.markupamntinlocal
              when '02' then ProposalItemCalc.grossingupbaseamntinlocal
              when '03' then ProposalItemCalc.grossingupmarginamntinlocal
              when '04' then ProposalItemCalc.latepaymentinterestamntinlocal
              when '05' then ProposalItemCalc.providergrossingupamntinlocal
              when '06' then ProposalItemCalc.AmountInCompanyCodeCurrency  // 06 is the base amount
            end                                        as AmountInCompanyCodeCurrency,
         _ProposalItemBasisDetails.CompanyCodeCurrency as CompanyCodeCurrency,
         _ProposalItem,
         _ProposalItemBasisDetails,
         _ProposalItemCalc,
         _ProposalItemBasisDetails._PandLFlat
}
where
  T.TariffType < '90' // Exclude 90+ codes (withholding workaround, not real tariffs)
