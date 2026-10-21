//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Proposal Item by Profit Center'
//@Metadata.ignorePropagatedAnnotations: true
//
//define root view entity ZI_IntercoProposalItemByCeBe
//  as select from ZI_IntercoProposalItemAux
//{
//  key Id,
//  key ProfitCenter,
//      Product,
//      ProductName,
//      BaseCurrencyProfitCenter,
//
//      // Monto total para Base Amount Corporate (D4 = 1)
//      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//      sum( case D4 when '1' then cast( Amount as abap.dec(23,2) ) else 0 end ) as Baseamountprofitcenter_sum,
//
//      // Monto total para Base Amount Hispanos (D4 = 3)
//      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//      sum( case D4 when '3' then cast( Amount as abap.dec(23,2) ) else 0 end ) as BaseamountprofitcenterH_sum,
//
//      // Monto total para Base Amount Locales (D4 = 0)
//      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//      sum( case D4 when '0' then cast( Amount as abap.dec(23,2) ) else 0 end ) as BaseamountprofitcenterL_sum,
//
//      // Total de receptores (clientes o proveedores)
//      //      sum( Quantity )                                                          as TotalRecipient,
//
//      // **Aquí añadimos el conteo de Company Codes**
//      count( distinct RecipientCompanyCode )                                   as NumberOfCompanyCodes,
//
//      // Cálculo final para Base Amount.
//      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//      case when count( distinct RecipientCompanyCode ) <> 0
//           then cast(
//             sum( case D4 when '1' then cast( Amount as abap.dec(23,2) ) else 0 end )
//             /
//             count( distinct RecipientCompanyCode )
//           as abap.dec(23,2) )
//           else 0
//      end                                                                      as Baseamountprofitcenter,
//
//      // Cálculo final para Base Amount H.
//      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//      case when count( distinct RecipientCompanyCode ) <> 0
//           then cast(
//             sum( case D4 when '3' then cast( Amount as abap.dec(23,2) ) else 0 end )
//             /
//             count( distinct RecipientCompanyCode )
//           as abap.dec(23,2) )
//           else 0
//      end                                                                      as BaseamountprofitcenterH,
//
//      // Cálculo final para Base Amount L.
//      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//      case when count( distinct RecipientCompanyCode ) <> 0
//           then cast(
//             sum( case D4 when '0' then cast( Amount as abap.dec(23,2) ) else 0 end )
//             /
//             count( distinct RecipientCompanyCode )
//           as abap.dec(23,2) )
//           else 0
//      end                                                                      as BaseamountprofitcenterL
//}
//group by
//  Id,
//  ProfitCenter,
//  Product,
//  ProductName,
//  BaseCurrencyProfitCenter
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Item by Profit Center / Company Code'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_IntercoProposalItemByCeBe

  -- ── RAMA 1A: Cost Sharing ANTES de ApplyMetric → 1 fila MLB ─────────────────
  as select from zfi_a_intrc_cph   as Header
    inner join   ZI_IntercoProduct as Product on Product.Product  = Header.product
                                              and(
                                                Product.Metric    = 'IC'
                                                or Product.Metric = 'CS'
                                              )
    inner join   I_CompanyCode     as Company on  Company.CompanyCode = Header.providercompanycode
                                              and Header.status       = ''
{
  key Header.id                                           as Id,
  key cast( Header.providercompanycode as abap.char(10) ) as ProfitCenter,
  key Header.product                                      as Product,

      Product.ProductName                                 as ProductName,
      Header.globalcurrency                               as BaseCurrencyProfitCenter,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      cast( 0 as abap.dec(23,2) )                         as Baseamountprofitcenter_sum,
      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      cast( 0 as abap.dec(23,2) )                         as BaseamountprofitcenterH_sum,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      cast( Header.amountinglobalcurrency
            as abap.dec(23,2) )                           as BaseamountprofitcenterL_sum,

      cast( 1 as abap.int8 )                              as NumberOfCompanyCodes,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      cast( 0 as abap.dec(23,2) )                         as Baseamountprofitcenter,
      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      cast( 0 as abap.dec(23,2) )                         as BaseamountprofitcenterH,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      cast( Header.amountinglobalcurrency
            as abap.dec(23,2) )                           as BaseamountprofitcenterL,

      cast( Header.providercompanycode as abap.char(10) ) as GroupCode,
      Company.CompanyCodeName                             as GroupName,
      cast( 'X' as abap_boolean )                         as IsCostSharing,
      cast( '' as abap_boolean )                          as IsBermudas,

      // ── NUEVO ─────────────────────────────────────────────────────────────
      Company.Currency                                    as CompanyCodeCurrency,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      cast( 0 as abap.dec(23,2) )                         as AmountInCompanyCodeCurrencyC,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      cast( 0 as abap.dec(23,2) )                         as AmountInCompanyCodeCurrencyH,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      cast( Header.amountincompanycodecurrency
            as abap.dec(23,2) )                           as AmountInCompanyCodeCurrencyL
      // ──────────────────────────────────────────────────────────────────────
}

union all

-- ── RAMA 1B: Cost Sharing DESPUÉS de ApplyMetric → N filas por sociedad ──────
select from ZI_IntercoProposalItemCS1B
{
  key Id,
  key cast( ProfitCenter as abap.char(10) ) as ProfitCenter,
  key Product,

      ProductName,
      BaseCurrencyProfitCenter,

      Baseamountprofitcenter_c              as Baseamountprofitcenter_sum,
      Baseamountprofitcenter_h              as BaseamountprofitcenterH_sum,
      Baseamountprofitcenter_l              as BaseamountprofitcenterL_sum,

      cast( 1 as abap.int8 )                as NumberOfCompanyCodes,

      Baseamountprofitcenter_c              as Baseamountprofitcenter,
      Baseamountprofitcenter_h              as BaseamountprofitcenterH,
      Baseamountprofitcenter_l              as BaseamountprofitcenterL,

      cast( GroupCode as abap.char(10) )    as GroupCode,
      GroupName,
      cast( 'X' as abap_boolean )           as IsCostSharing,
      cast( '' as abap_boolean )            as IsBermudas,
      // ── NUEVO ─────────────────────────────────────────────────────────────
      CompanyCodeCurrency,
      AmountInCompanyCodeCurrencyC,
      AmountInCompanyCodeCurrencyH,
      AmountInCompanyCodeCurrencyL
      // ──────────────────────────────────────────────────────────────────────
}

union all

-- ── RAMA 2: Resto de materiales → lógica ByCeBe original sin cambio ──────────
// Rama 2 ahora excluye Metric = 'SM' (and Prod.Metric <> 'SM') para que las
// propuestas de Bermudas se agrupen SOLO por P&L L0 en la Rama 3 y no se
// dupliquen contra la agrupación por CeBe de esta rama.
select from  ZI_IntercoProposalItemAux
  inner join ZI_IntercoProduct as Prod on  Prod.Product =  ZI_IntercoProposalItemAux.Product
                                       and Prod.Metric  <> 'IC'
                                       and Prod.Metric  <> 'CS'
                                       and Prod.Metric  <> 'SM'
{
  key ZI_IntercoProposalItemAux.Id,
  key ZI_IntercoProposalItemAux.ProfitCenter,
  key ZI_IntercoProposalItemAux.Product,

      ZI_IntercoProposalItemAux.ProductName,
      ZI_IntercoProposalItemAux.BaseCurrencyProfitCenter,

      sum( case ZI_IntercoProposalItemAux.D4
             when '1' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
             else cast( 0 as abap.dec(23,2) )
           end )                                                       as Baseamountprofitcenter_sum,

      sum( case ZI_IntercoProposalItemAux.D4
             when '3' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
             else cast( 0 as abap.dec(23,2) )
           end )                                                       as BaseamountprofitcenterH_sum,

      sum( case ZI_IntercoProposalItemAux.D4
             when '0' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
             else cast( 0 as abap.dec(23,2) )
           end )                                                       as BaseamountprofitcenterL_sum,

      count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) as NumberOfCompanyCodes,

      case when count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) <> 0
           then cast(
             sum( case ZI_IntercoProposalItemAux.D4
                    when '1' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
                    else cast( 0 as abap.dec(23,2) )
                  end )
             / count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode )
           as abap.dec(23,2) )
           else cast( 0 as abap.dec(23,2) )
      end                                                              as Baseamountprofitcenter,

      case when count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) <> 0
           then cast(
             sum( case ZI_IntercoProposalItemAux.D4
                    when '3' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
                    else cast( 0 as abap.dec(23,2) )
                  end )
             / count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode )
           as abap.dec(23,2) )
           else cast( 0 as abap.dec(23,2) )
      end                                                              as BaseamountprofitcenterH,

      case when count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) <> 0
           then cast(
             sum( case ZI_IntercoProposalItemAux.D4
                    when '0' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
                    else cast( 0 as abap.dec(23,2) )
                  end )
             / count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode )
           as abap.dec(23,2) )
           else cast( 0 as abap.dec(23,2) )
      end                                                              as BaseamountprofitcenterL,

      ZI_IntercoProposalItemAux.ProfitCenter                           as GroupCode,
      cast( '' as abap.char(60) )                                      as GroupName,
      cast( '' as abap_boolean )                                       as IsCostSharing,
      cast( '' as abap_boolean )                                       as IsBermudas,
      // ── NUEVO: ceros para rama 2 (no aplica moneda local) ─────────────────
      cast( '' as zint_dte_fis_hwaer )                                 as CompanyCodeCurrency,
      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyC,
      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyH,
      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyL
      // ──────────────────────────────────────────────────────────────────────
}
group by
  ZI_IntercoProposalItemAux.Id,
  ZI_IntercoProposalItemAux.ProfitCenter,
  ZI_IntercoProposalItemAux.Product,
  ZI_IntercoProposalItemAux.ProductName,
  ZI_IntercoProposalItemAux.BaseCurrencyProfitCenter

union all

-- ── RAMA 3: Bermudas MIC — agrupacion por categoria P&L L0 (Metric = 'SM') ──
select from  ZI_IntercoProposalItemOrGLAcct as OrGL
  inner join ZI_IntercoProposal             as Proposal on Proposal.Id = OrGL.Id
  inner join ZI_IntercoProduct              as Prod     on  Prod.Product = Proposal.Product
                                                        and Prod.Metric  = 'SM'
  inner join ZI_IntercoPandLHierFlattened   as PandL    on PandL.ID = OrGL.PandLL5ID
  inner join ZI_IntercoPandLHierFlattened   as PandL_L0 on PandL_L0.ID = PandL.IDL0
{
  key OrGL.Id,
  key cast( PandL.IDL0 as abap.char(10) )                          as ProfitCenter,
  key Proposal.Product                                             as Product,

      Prod.ProductName                                             as ProductName,
      OrGL.GlobalCurrency                                          as BaseCurrencyProfitCenter,

      sum( cast( OrGL.AmountInGlobalCurrency as abap.dec(23,2) ) ) as Baseamountprofitcenter_sum,

      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterH_sum,

      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterL_sum,

      cast( 1 as abap.int8 )                                       as NumberOfCompanyCodes,

      sum( cast( OrGL.AmountInGlobalCurrency as abap.dec(23,2) ) ) as Baseamountprofitcenter,

      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterH,

      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterL,

      cast( PandL.IDL0 as abap.char(10) )                          as GroupCode,
      PandL_L0.Text                                                as GroupName,

      cast( '' as abap_boolean )                                   as IsCostSharing,
      cast( 'X' as abap_boolean )                                  as IsBermudas,

      cast( '' as zint_dte_fis_hwaer )                             as CompanyCodeCurrency,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyC,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyH,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyL
}
group by
  OrGL.Id,
  PandL.IDL0,
  Proposal.Product,
  Prod.ProductName,
  OrGL.GlobalCurrency,
  PandL_L0.Text
