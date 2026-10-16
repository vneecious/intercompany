-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: fuente anterior conservada comentada; se agregan exclusiones L e IsLocal
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Proposal Item by Profit Center / Company Code'
//@Metadata.ignorePropagatedAnnotations: true
//
//define root view entity ZI_IntercoProposalItemByCeBe
//
//  -- ── RAMA 1A: Cost Sharing ANTES de ApplyMetric → 1 fila MLB ─────────────────
//  as select from zfi_a_intrc_cph   as Header
//    inner join   ZI_IntercoProduct as Product on Product.Product  = Header.product
//                                              and(
//                                                Product.Metric    = 'IC'
//                                                or Product.Metric = 'CS'
//                                              )
//    inner join   I_CompanyCode     as Company on  Company.CompanyCode = Header.providercompanycode
//                                              and Header.status       = ''
//{
//  key Header.id                                           as Id,
//  key cast( Header.providercompanycode as abap.char(10) ) as ProfitCenter,
//  key Header.product                                      as Product,
//
//      Product.ProductName                                 as ProductName,
//      Header.globalcurrency                               as BaseCurrencyProfitCenter,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( 0 as abap.dec(23,2) )                         as Baseamountprofitcenter_sum,
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( 0 as abap.dec(23,2) )                         as BaseamountprofitcenterH_sum,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( Header.amountinglobalcurrency
//            as abap.dec(23,2) )                           as BaseamountprofitcenterL_sum,
//
//      cast( 1 as abap.int8 )                              as NumberOfCompanyCodes,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( 0 as abap.dec(23,2) )                         as Baseamountprofitcenter,
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( 0 as abap.dec(23,2) )                         as BaseamountprofitcenterH,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( Header.amountinglobalcurrency
//            as abap.dec(23,2) )                           as BaseamountprofitcenterL,
//
//      cast( Header.providercompanycode as abap.char(10) ) as GroupCode,
//      Company.CompanyCodeName                             as GroupName,
//      cast( 'X' as abap_boolean )                         as IsCostSharing,
//      cast( '' as abap_boolean )                          as IsBermudas,
//
//      // ── NUEVO ─────────────────────────────────────────────────────────────
//      Company.Currency                                    as CompanyCodeCurrency,
//
//      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
//      cast( 0 as abap.dec(23,2) )                         as AmountInCompanyCodeCurrencyC,
//      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
//      cast( 0 as abap.dec(23,2) )                         as AmountInCompanyCodeCurrencyH,
//
//      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
//      cast( Header.amountincompanycodecurrency
//            as abap.dec(23,2) )                           as AmountInCompanyCodeCurrencyL
//      // ──────────────────────────────────────────────────────────────────────
//}
//
//union all
//
//-- ── RAMA 1B: Cost Sharing DESPUÉS de ApplyMetric → N filas por sociedad ──────
//select from ZI_IntercoProposalItemCS1B
//{
//  key Id,
//  key cast( ProfitCenter as abap.char(10) ) as ProfitCenter,
//  key Product,
//
//      ProductName,
//      BaseCurrencyProfitCenter,
//
//      Baseamountprofitcenter_c              as Baseamountprofitcenter_sum,
//      Baseamountprofitcenter_h              as BaseamountprofitcenterH_sum,
//      Baseamountprofitcenter_l              as BaseamountprofitcenterL_sum,
//
//      cast( 1 as abap.int8 )                as NumberOfCompanyCodes,
//
//      Baseamountprofitcenter_c              as Baseamountprofitcenter,
//      Baseamountprofitcenter_h              as BaseamountprofitcenterH,
//      Baseamountprofitcenter_l              as BaseamountprofitcenterL,
//
//      cast( GroupCode as abap.char(10) )    as GroupCode,
//      GroupName,
//      cast( 'X' as abap_boolean )           as IsCostSharing,
//      cast( '' as abap_boolean )            as IsBermudas,
//      // ── NUEVO ─────────────────────────────────────────────────────────────
//      CompanyCodeCurrency,
//      AmountInCompanyCodeCurrencyC,
//      AmountInCompanyCodeCurrencyH,
//      AmountInCompanyCodeCurrencyL
//      // ──────────────────────────────────────────────────────────────────────
//}
//
//union all
//
//-- ── RAMA 2: Resto de materiales → lógica ByCeBe original sin cambio ──────────
//// Rama 2 ahora excluye Metric = 'SM' (and Prod.Metric <> 'SM') para que las
//// propuestas de Bermudas se agrupen SOLO por P&L L0 en la Rama 3 y no se
//// dupliquen contra la agrupación por CeBe de esta rama.
//select from  ZI_IntercoProposalItemAux
//  inner join ZI_IntercoProduct as Prod on  Prod.Product =  ZI_IntercoProposalItemAux.Product
//                                       and Prod.Metric  <> 'IC'
//                                       and Prod.Metric  <> 'CS'
//                                       and Prod.Metric  <> 'SM'
//{
//  key ZI_IntercoProposalItemAux.Id,
//  key ZI_IntercoProposalItemAux.ProfitCenter,
//  key ZI_IntercoProposalItemAux.Product,
//
//      ZI_IntercoProposalItemAux.ProductName,
//      ZI_IntercoProposalItemAux.BaseCurrencyProfitCenter,
//
//      sum( case ZI_IntercoProposalItemAux.D4
//             when '1' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
//             else cast( 0 as abap.dec(23,2) )
//           end )                                                       as Baseamountprofitcenter_sum,
//
//      sum( case ZI_IntercoProposalItemAux.D4
//             when '3' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
//             else cast( 0 as abap.dec(23,2) )
//           end )                                                       as BaseamountprofitcenterH_sum,
//
//      sum( case ZI_IntercoProposalItemAux.D4
//             when '0' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
//             else cast( 0 as abap.dec(23,2) )
//           end )                                                       as BaseamountprofitcenterL_sum,
//
//      count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) as NumberOfCompanyCodes,
//
//      case when count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) <> 0
//           then cast(
//             sum( case ZI_IntercoProposalItemAux.D4
//                    when '1' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
//                    else cast( 0 as abap.dec(23,2) )
//                  end )
//             / count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode )
//           as abap.dec(23,2) )
//           else cast( 0 as abap.dec(23,2) )
//      end                                                              as Baseamountprofitcenter,
//
//      case when count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) <> 0
//           then cast(
//             sum( case ZI_IntercoProposalItemAux.D4
//                    when '3' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
//                    else cast( 0 as abap.dec(23,2) )
//                  end )
//             / count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode )
//           as abap.dec(23,2) )
//           else cast( 0 as abap.dec(23,2) )
//      end                                                              as BaseamountprofitcenterH,
//
//      case when count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode ) <> 0
//           then cast(
//             sum( case ZI_IntercoProposalItemAux.D4
//                    when '0' then cast( ZI_IntercoProposalItemAux.Amount as abap.dec(23,2) )
//                    else cast( 0 as abap.dec(23,2) )
//                  end )
//             / count( distinct ZI_IntercoProposalItemAux.RecipientCompanyCode )
//           as abap.dec(23,2) )
//           else cast( 0 as abap.dec(23,2) )
//      end                                                              as BaseamountprofitcenterL,
//
//      ZI_IntercoProposalItemAux.ProfitCenter                           as GroupCode,
//      cast( '' as abap.char(60) )                                      as GroupName,
//      cast( '' as abap_boolean )                                       as IsCostSharing,
//      cast( '' as abap_boolean )                                       as IsBermudas,
//      // ── NUEVO: ceros para rama 2 (no aplica moneda local) ─────────────────
//      cast( '' as zint_dte_fis_hwaer )                                 as CompanyCodeCurrency,
//      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyC,
//      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyH,
//      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyL
//      // ──────────────────────────────────────────────────────────────────────
//}
//group by
//  ZI_IntercoProposalItemAux.Id,
//  ZI_IntercoProposalItemAux.ProfitCenter,
//  ZI_IntercoProposalItemAux.Product,
//  ZI_IntercoProposalItemAux.ProductName,
//  ZI_IntercoProposalItemAux.BaseCurrencyProfitCenter
//
//union all
//
//-- ── RAMA 3: Bermudas MIC — agrupacion por categoria P&L L0 (Metric = 'SM') ──
//select from  ZI_IntercoProposalItemOrGLAcct as OrGL
//  inner join ZI_IntercoProposal             as Proposal on Proposal.Id = OrGL.Id
//  inner join ZI_IntercoProduct              as Prod     on  Prod.Product = Proposal.Product
//                                                        and Prod.Metric  = 'SM'
//  inner join ZI_IntercoPandLHierFlattened   as PandL    on PandL.ID = OrGL.PandLL5ID
//  inner join ZI_IntercoPandLHierFlattened   as PandL_L0 on PandL_L0.ID = PandL.IDL0
//{
//  key OrGL.Id,
//  key cast( PandL.IDL0 as abap.char(10) )                          as ProfitCenter,
//  key Proposal.Product                                             as Product,
//
//      Prod.ProductName                                             as ProductName,
//      OrGL.GlobalCurrency                                          as BaseCurrencyProfitCenter,
//
//      sum( cast( OrGL.AmountInGlobalCurrency as abap.dec(23,2) ) ) as Baseamountprofitcenter_sum,
//
//      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterH_sum,
//
//      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterL_sum,
//
//      cast( 1 as abap.int8 )                                       as NumberOfCompanyCodes,
//
//      sum( cast( OrGL.AmountInGlobalCurrency as abap.dec(23,2) ) ) as Baseamountprofitcenter,
//
//      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterH,
//
//      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterL,
//
//      cast( PandL.IDL0 as abap.char(10) )                          as GroupCode,
//      PandL_L0.Text                                                as GroupName,
//
//      cast( '' as abap_boolean )                                   as IsCostSharing,
//      cast( 'X' as abap_boolean )                                  as IsBermudas,
//
//      cast( '' as zint_dte_fis_hwaer )                             as CompanyCodeCurrency,
//      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyC,
//      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyH,
//      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyL
//}
//group by
//  OrGL.Id,
//  PandL.IDL0,
//  Proposal.Product,
//  Prod.ProductName,
//  OrGL.GlobalCurrency,
//  PandL_L0.Text

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
-- Fin EXT_OSCUGALD 14.10.2026 - C23

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Item by Profit Center / Company Code'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_IntercoProposalItemByCeBe

  -- ── RAMA 1A: Cost Sharing ANTES de ApplyMetric → 1 fila MLB ─────────────────
  as select from    zfi_a_intrc_cph   as Header
    inner join      ZI_IntercoProduct as Product    on Product.Product  = Header.product
                                                    and(
                                                      Product.Metric    = 'IC'
                                                      or Product.Metric = 'CS'
                                                    )
    inner join      I_CompanyCode     as Company    on  Company.CompanyCode = Header.providercompanycode
                                                    and Header.status       = ''
  -- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: identificar tipo de Base sin perder históricos
    left outer join ZI_INTERCOBASIS   as LocalBasis on LocalBasis.Id = Header.intercobasisid
  -- Fin EXT_OSCUGALD 14.10.2026 - C23
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
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: indicador Local independiente
      cast( '' as abap_boolean )                          as IsLocal,
      -- Fin EXT_OSCUGALD 14.10.2026 - C23
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
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: excluir solo L de la ruta histórica
where
  coalesce( LocalBasis.PaymentType, '' ) <> 'L'
-- Fin EXT_OSCUGALD 14.10.2026 - C23

union all

-- RAMA 1B: Cost Sharing DESPUÉS de ApplyMetric; cálculos de CS1B conservados
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: referenciar cabecera para excluir Locales
select from       ZI_IntercoProposalItemCS1B as CS
  left outer join ZI_IntercoProposal         as LocalProposal on LocalProposal.Id = CS.Id
-- Fin EXT_OSCUGALD 14.10.2026 - C23
{
  key CS.Id,
  key cast( CS.ProfitCenter as abap.char(10) ) as ProfitCenter,
  key CS.Product,
      CS.ProductName,
      CS.BaseCurrencyProfitCenter,
      CS.Baseamountprofitcenter_c              as Baseamountprofitcenter_sum,
      CS.Baseamountprofitcenter_h              as BaseamountprofitcenterH_sum,
      CS.Baseamountprofitcenter_l              as BaseamountprofitcenterL_sum,
      cast( 1 as abap.int8 )                   as NumberOfCompanyCodes,
      CS.Baseamountprofitcenter_c              as Baseamountprofitcenter,
      CS.Baseamountprofitcenter_h              as BaseamountprofitcenterH,
      CS.Baseamountprofitcenter_l              as BaseamountprofitcenterL,
      cast( CS.GroupCode as abap.char(10) )    as GroupCode,
      CS.GroupName,
      cast( 'X' as abap_boolean )              as IsCostSharing,
      cast( '' as abap_boolean )               as IsBermudas,
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: indicador Local independiente
      cast( '' as abap_boolean )               as IsLocal,
      -- Fin EXT_OSCUGALD 14.10.2026 - C23
      CS.CompanyCodeCurrency,
      CS.AmountInCompanyCodeCurrencyC,
      CS.AmountInCompanyCodeCurrencyH,
      CS.AmountInCompanyCodeCurrencyL
}
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: excluir solo L de la ruta histórica
where
  coalesce( LocalProposal.PaymentType, '' ) <> 'L'
-- Fin EXT_OSCUGALD 14.10.2026 - C23

union all

-- ── RAMA 2: Resto de materiales → lógica ByCeBe original sin cambio ──────────
// Rama 2 ahora excluye Metric = 'SM' (and Prod.Metric <> 'SM') para que las
// propuestas de Bermudas se agrupen SOLO por P&L L0 en la Rama 3 y no se
// dupliquen contra la agrupación por CeBe de esta rama.
select from       ZI_IntercoProposalItemAux
  inner join      ZI_IntercoProduct  as Prod          on  Prod.Product =  ZI_IntercoProposalItemAux.Product
                                                      and Prod.Metric  <> 'IC'
                                                      and Prod.Metric  <> 'CS'
                                                      and Prod.Metric  <> 'SM'
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: identificar tipo de Base sin perder históricos
  left outer join ZI_IntercoProposal as LocalProposal on LocalProposal.Id = ZI_IntercoProposalItemAux.Id
-- Fin EXT_OSCUGALD 14.10.2026 - C23
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
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: indicador Local independiente
      cast( '' as abap_boolean )                                       as IsLocal,
      -- Fin EXT_OSCUGALD 14.10.2026 - C23
      // ── NUEVO: ceros para rama 2 (no aplica moneda local) ─────────────────
      cast( '' as zint_dte_fis_hwaer )                                 as CompanyCodeCurrency,
      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyC,
      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyH,
      cast( 0 as abap.dec(23,2) )                                      as AmountInCompanyCodeCurrencyL
      // ──────────────────────────────────────────────────────────────────────
}
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: excluir solo L de la ruta histórica
where
  coalesce( LocalProposal.PaymentType, '' ) <> 'L'
-- Fin EXT_OSCUGALD 14.10.2026 - C23
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
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: indicador Local independiente
      cast( '' as abap_boolean )                                   as IsLocal,
      -- Fin EXT_OSCUGALD 14.10.2026 - C23
      cast( '' as zint_dte_fis_hwaer )                             as CompanyCodeCurrency,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyC,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyH,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyL
}
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: excluir solo L de la ruta histórica
where
  coalesce( Proposal.PaymentType, '' ) <> 'L'
-- Fin EXT_OSCUGALD 14.10.2026 - C23
group by
  OrGL.Id,
  PandL.IDL0,
  Proposal.Product,
  Prod.ProductName,
  OrGL.GlobalCurrency,
  PandL_L0.Text

union all
-- Ini Facturación Local CH/ARG EXT_OSCUGALD 14.10.2026 - C23: Rama 4 Local, antes y después de métricas

-- RAMA 4A: Local ANTES de ApplyMetric; una fila por proveedora
select from  zfi_a_intrc_cph   as Header
  inner join ZI_INTERCOBASIS   as LocalBasis on LocalBasis.Id = Header.intercobasisid
  inner join ZI_IntercoProduct as Product    on Product.Product = Header.product
  inner join I_CompanyCode     as Company    on Company.CompanyCode = Header.providercompanycode
{
  key Header.id                                                    as Id,
  key cast( Header.providercompanycode as abap.char(10) )          as ProfitCenter,
  key Header.product                                               as Product,
      Product.ProductName                                          as ProductName,
      Header.globalcurrency                                        as BaseCurrencyProfitCenter,
      cast( 0 as abap.dec(23,2) )                                  as Baseamountprofitcenter_sum,
      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterH_sum,
      cast( Header.amountinglobalcurrency as abap.dec(23,2) )      as BaseamountprofitcenterL_sum,
      cast( 1 as abap.int8 )                                       as NumberOfCompanyCodes,
      cast( 0 as abap.dec(23,2) )                                  as Baseamountprofitcenter,
      cast( 0 as abap.dec(23,2) )                                  as BaseamountprofitcenterH,
      cast( Header.amountinglobalcurrency as abap.dec(23,2) )      as BaseamountprofitcenterL,
      cast( Header.providercompanycode as abap.char(10) )          as GroupCode,
      Company.CompanyCodeName                                      as GroupName,
      cast( '' as abap_boolean )                                   as IsCostSharing,
      cast( '' as abap_boolean )                                   as IsBermudas,
      cast( 'X' as abap_boolean )                                  as IsLocal,
      Company.Currency                                             as CompanyCodeCurrency,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyC,
      cast( 0 as abap.dec(23,2) )                                  as AmountInCompanyCodeCurrencyH,
      cast( Header.amountincompanycodecurrency as abap.dec(23,2) ) as AmountInCompanyCodeCurrencyL
}
where
      LocalBasis.PaymentType = 'L'
  and Header.status          = ''

union all

-- RAMA 4B: Local DESPUÉS de ApplyMetric; una fila por prestataria y monedas
select from  zfi_a_intrc_cpi   as Item
  inner join zfi_a_intrc_cph   as Header     on Header.id = Item.id
  inner join ZI_INTERCOBASIS   as LocalBasis on LocalBasis.Id = Header.intercobasisid
  inner join ZI_IntercoProduct as Product    on Product.Product = Header.product
  inner join I_CompanyCode     as Company    on Company.CompanyCode = Item.recipientcompanycode
{
  key Item.id                                                             as Id,
  key cast( Item.recipientcompanycode as abap.char(10) )                  as ProfitCenter,
  key Header.product                                                      as Product,
      Product.ProductName                                                 as ProductName,
      Item.basecurrencyprofitcenter                                       as BaseCurrencyProfitCenter,
      sum( cast( Item.baseamountprofitcenter_c as abap.dec(23,2) ) )      as Baseamountprofitcenter_sum,
      sum( cast( Item.baseamountprofitcenter_h as abap.dec(23,2) ) )      as BaseamountprofitcenterH_sum,
      sum( cast( Item.baseamountprofitcenter_l as abap.dec(23,2) ) )      as BaseamountprofitcenterL_sum,
      cast( 1 as abap.int8 )                                              as NumberOfCompanyCodes,
      sum( cast( Item.baseamountprofitcenter_c as abap.dec(23,2) ) )      as Baseamountprofitcenter,
      sum( cast( Item.baseamountprofitcenter_h as abap.dec(23,2) ) )      as BaseamountprofitcenterH,
      sum( cast( Item.baseamountprofitcenter_l as abap.dec(23,2) ) )      as BaseamountprofitcenterL,
      cast( Item.recipientcompanycode as abap.char(10) )                  as GroupCode,
      Company.CompanyCodeName                                             as GroupName,
      cast( '' as abap_boolean )                                          as IsCostSharing,
      cast( '' as abap_boolean )                                          as IsBermudas,
      cast( 'X' as abap_boolean )                                         as IsLocal,
      Item.companycodecurrency                                            as CompanyCodeCurrency,
      sum( cast( Item.amountincompanycodecurrency_c as abap.dec(23,2) ) ) as AmountInCompanyCodeCurrencyC,
      sum( cast( Item.amountincompanycodecurrency_h as abap.dec(23,2) ) ) as AmountInCompanyCodeCurrencyH,
      sum( cast( Item.amountincompanycodecurrency_l as abap.dec(23,2) ) ) as AmountInCompanyCodeCurrencyL
}
where
      LocalBasis.PaymentType =  'L'
  and Header.status          <> ''
group by
  Item.id,
  Item.recipientcompanycode,
  Header.product,
  Product.ProductName,
  Item.basecurrencyprofitcenter,
  Item.companycodecurrency,
  Company.CompanyCodeName

-- Fin EXT_OSCUGALD 14.10.2026 - C23
