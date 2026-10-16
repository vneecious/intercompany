/**
 * This View is designed to add P&L data to the Intercompany JE Items.
 * Intercompany Basis View Hierarchy:
 * ZR_IntercoJEItemClass
 *  - ZI_IntercoJEItemClass
 *      - ZI_IntercoJEItemClassMatch
 *          - ZI_IntercoJEItemClassRule
 *              - ZI_IntercoJEItemPandL <------- CURRENT VIEW
 *                  - ZI_IntercoJEItem
 *
 */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany / Basis: Journal Entry Item w/ P&L'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define view entity ZI_IntercoJEItemPandL
  as select from ZI_IntercoJEItem
  association [0..1] to ZI_IntercoBasisItem       as _CurrentBasisItem     on  _CurrentBasisItem.Ledger              = $projection.Ledger
                                                                           and _CurrentBasisItem.Glaccount           = $projection.GLAccount
                                                                           and _CurrentBasisItem.Costcenter          = $projection.CostCenter
                                                                           and _CurrentBasisItem.Fiscalyear          = $projection.FiscalYear
                                                                           and _CurrentBasisItem.Fiscalperiod        = $projection.FiscalPeriod
                                                                           and _CurrentBasisItem.Providercompanycode = $projection.CompanyCode
                                                                           and _CurrentBasisItem.Profitcenter        = $projection.ProfitCenter
                                                                           and $projection.CreationDateTime          between _CurrentBasisItem.MinDateTime and _CurrentBasisItem.MaxDateTime
/* ELIMINADO DS4K9B5URA: asociación _MT005 única con condición OR/IS INITIAL en el ON.
   CCConsolidationParentNode es NULL en HANA cuando no hay jerarquía CC (asociación [0..*] sin match).
   CDS compila IS INITIAL como = '' en SQL → NULL = '' siempre es FALSE → ambas branches del OR
   son FALSE → _MT005 nunca hace join para ítems sin CCConsolidation → PandLL0Id queda vacío.
  association [0..1] to Z_PNL_MT005 as _MT005 on (
    _MT005.zagrup_cuentas = $projection.GLAccountParentNode
    or _MT005.temp_zagrup_cuentas = $projection.GLAccountParentNode
  )
  and (
    ($projection.CCConsolidationParentNode is not initial
     and _MT005.zconsolidation = $projection.CCConsolidationParentNode)
    or ($projection.CCConsolidationParentNode is initial
        and _MT005.zconsolidation = $projection.PCConsolidationParentNode)
  )
*/
/* ELIMINADO (fix performance): dos asociaciones _MT005CC/_MT005PC con OR en el ON
   (zagrup_cuentas = X or temp_zagrup_cuentas = X). El OR contra una columna calculada
   (temp_zagrup_cuentas = concat('0', zagrup_cuentas) en Z_PNL_MT005) impide al optimizador
   de HANA armar un hash join limpio; con ~13,8M de lineas JE por companycode/periodo/ledger
   (ej. EBA 2026/001/L1) esto fuerza un plan mucho mas costoso y termina en timeout en
   materialize_agrupadores (ZCL_INTERCO_CLASS_ENGINE).
  association [0..1] to Z_PNL_MT005               as _MT005CC              on  (
                     _MT005CC.zagrup_cuentas                                                                         = $projection.GLAccountParentNode
                     or _MT005CC.temp_zagrup_cuentas                                                                 = $projection.GLAccountParentNode
                   )
                                                                           and _MT005CC.zconsolidation               = $projection.CCConsolidationParentNode
  association [0..1] to Z_PNL_MT005               as _MT005PC              on  (
                     _MT005PC.zagrup_cuentas                                                                         = $projection.GLAccountParentNode
                     or _MT005PC.temp_zagrup_cuentas                                                                 = $projection.GLAccountParentNode
                   )
                                                                           and _MT005PC.zconsolidation               = $projection.PCConsolidationParentNode
*/
/* AGREGADO (fix performance): cada rama del OR pasa a ser una asociacion propia con
   predicado unico (equi-join), sin cambiar el resultado (misma suposicion de cardinalidad
   [0..1] que ya asumia el codigo anterior: para un GLAccountParentNode+zconsolidation dado,
   como maximo una de las dos ramas matchea). El coalesce en la projection list elige la que
   matcheo, en el mismo orden de prioridad CC > PC que ya existia. */
  association [0..1] to Z_PNL_MT005               as _MT005CC_STD          on  _MT005CC_STD.zagrup_cuentas      = $projection.GLAccountParentNode
                                                                           and _MT005CC_STD.zconsolidation       = $projection.CCConsolidationParentNode
  association [0..1] to Z_PNL_MT005               as _MT005CC_TMP          on  _MT005CC_TMP.temp_zagrup_cuentas = $projection.GLAccountParentNode
                                                                           and _MT005CC_TMP.zconsolidation       = $projection.CCConsolidationParentNode
  association [0..1] to Z_PNL_MT005               as _MT005PC_STD          on  _MT005PC_STD.zagrup_cuentas      = $projection.GLAccountParentNode
                                                                           and _MT005PC_STD.zconsolidation       = $projection.PCConsolidationParentNode
  association [0..1] to Z_PNL_MT005               as _MT005PC_TMP          on  _MT005PC_TMP.temp_zagrup_cuentas = $projection.GLAccountParentNode
                                                                           and _MT005PC_TMP.zconsolidation       = $projection.PCConsolidationParentNode

  association [0..*] to I_CostCenterHierarchyNode as _CCStdGrandParentNode on  _CCStdGrandParentNode.CostCenterHierarchy = $projection.CCStdHierarchy
                                                                           and _CCStdGrandParentNode.ControllingArea     = $projection.ControllingArea
                                                                           and _CCStdGrandParentNode.HierarchyNode       = $projection.CCStdGrandParentNode
                                                                           and $projection.CostCenter                    is not initial

{
  key SourceLedger,
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
  key AccountingDocument,
  key LedgerGLLineItem,
  key Ledger,

      Segment,
      AccountingDocumentType,
      AccountingDocumentItem,
      DebitCreditCode,
      AccountingDocumentCategory,
      LedgerFiscalYear,
      ClearingAccountingDocument,
      ClearingJournalEntry,
      ClearingDate,
      ClearingDocFiscalYear,
      ClearingJournalEntryFiscalYear,
      IsOpenItemManaged,
      TransactionCurrency,
      AmountInTransactionCurrency,
      CompanyCodeCurrency,
      AmountInCompanyCodeCurrency,
      GlobalCurrency,
      AmountInGlobalCurrency,
      CreationDate,
      FiscalYearPeriod,
      OriginObjectType,

      ProfitCenter,
      PostingDate,
      CreationDateTime,
      CostCenter,
      ControllingArea,
      PaymentType,
      CostCenterStandardHierArea,
      ChartOfAccounts,
      GLAccount,
      GLAccountHierarchy,
      GLAccountHierarchyNode,
      GLAccountParentNode,
      GLAccountParentNodeTEMP,
      GLAccountParentNodeTEMPlen,
      // CC Consolidation
      ZI_IntercoJEItem.CCConsolidationHierarchy,
      CCConsolidationHierarchyNode,
      CCConsolidationParentNode,
      cast( _CCConsolidationParentNode.HierarchyNodeVal as zint_cc_cons ) as CCConsolidation,
      // PC Consolidation
      PCConsolidationHierarchy,
      PCConsolidationHierarchyNode,
      PCConsolidationParentNode,
      _PCConsolidationParentNode.HierarchyNodeVal                         as PCConsolidation,
      // CC Allocation
      CCAllocationHierarchy,
      CCAllocationHierarchyNode,
      CCAllocationParentNode,
      cast( _CCAllocationParentNode.HierarchyNodeVal as zint_cc_alloc)    as CCAllocation,
      // CC Std Hierarchy
      ZI_IntercoJEItem.CCStdHierarchy,
      ZI_IntercoJEItem.CCStdParentNode,
      _CCStdParentNode.ParentNode                                         as CCStdGrandParentNode,
      // PC Std Hierarchy
      PCBusinessUnit,
      PCSubBusinessUnitGroup,
      PCSubBusinessUnit,
/* ELIMINADO DS4K9B5URA: _MT005.xxx → reemplazado por coalesce(_MT005CC.xxx, _MT005PC.xxx)
      _MT005.zagrup_cuentas,
      _MT005.zconsolidation,
      _MT005.IdL0 as PandLL0Id,
      _MT005.IdL1 as PandLL1Id,
      _MT005.IdL2 as PandLL2Id,
      _MT005.IdL3 as PandLL3Id,
      _MT005.IdL4 as PandLL4Id,
      _MT005.IdL5 as PandLL5Id,
      _MT005.L0   as PandLL0Name,
      _MT005.L1   as PandLL1Name,
      _MT005.L2   as PandLL2Name,
      _MT005.L3   as PandLL3Name,
      _MT005.L4   as PandLL4Name,
      _MT005.L5   as PandLL5Name,
*/
/* ELIMINADO (fix performance): coalesce sobre _MT005CC/_MT005PC (asociaciones con OR)
      coalesce(_MT005CC.zagrup_cuentas, _MT005PC.zagrup_cuentas)          as zagrup_cuentas,
      coalesce(_MT005CC.zconsolidation, _MT005PC.zconsolidation)          as zconsolidation,
      coalesce(_MT005CC.IdL0, _MT005PC.IdL0)                              as PandLL0Id,
      coalesce(_MT005CC.IdL1, _MT005PC.IdL1)                              as PandLL1Id,
      coalesce(_MT005CC.IdL2, _MT005PC.IdL2)                              as PandLL2Id,
      coalesce(_MT005CC.IdL3, _MT005PC.IdL3)                              as PandLL3Id,
      coalesce(_MT005CC.IdL4, _MT005PC.IdL4)                              as PandLL4Id,
      coalesce(_MT005CC.IdL5, _MT005PC.IdL5)                              as PandLL5Id,
      coalesce(_MT005CC.L0, _MT005PC.L0)                                  as PandLL0Name,
      coalesce(_MT005CC.L1, _MT005PC.L1)                                  as PandLL1Name,
      coalesce(_MT005CC.L2, _MT005PC.L2)                                  as PandLL2Name,
      coalesce(_MT005CC.L3, _MT005PC.L3)                                  as PandLL3Name,
      coalesce(_MT005CC.L4, _MT005PC.L4)                                  as PandLL4Name,
      coalesce(_MT005CC.L5, _MT005PC.L5)                                  as PandLL5Name,
*/
/* AGREGADO (fix performance): mismo resultado, ahora con 4 asociaciones de equi-join puro.
   coalesce() en este release de CDS solo acepta 2 parametros -> se anida de a pares. */
      coalesce(coalesce(_MT005CC_STD.zagrup_cuentas, _MT005CC_TMP.zagrup_cuentas), coalesce(_MT005PC_STD.zagrup_cuentas, _MT005PC_TMP.zagrup_cuentas)) as zagrup_cuentas,
      coalesce(coalesce(_MT005CC_STD.zconsolidation, _MT005CC_TMP.zconsolidation), coalesce(_MT005PC_STD.zconsolidation, _MT005PC_TMP.zconsolidation)) as zconsolidation,
      coalesce(coalesce(_MT005CC_STD.IdL0, _MT005CC_TMP.IdL0), coalesce(_MT005PC_STD.IdL0, _MT005PC_TMP.IdL0))                                         as PandLL0Id,
      coalesce(coalesce(_MT005CC_STD.IdL1, _MT005CC_TMP.IdL1), coalesce(_MT005PC_STD.IdL1, _MT005PC_TMP.IdL1))                                         as PandLL1Id,
      coalesce(coalesce(_MT005CC_STD.IdL2, _MT005CC_TMP.IdL2), coalesce(_MT005PC_STD.IdL2, _MT005PC_TMP.IdL2))                                         as PandLL2Id,
      coalesce(coalesce(_MT005CC_STD.IdL3, _MT005CC_TMP.IdL3), coalesce(_MT005PC_STD.IdL3, _MT005PC_TMP.IdL3))                                         as PandLL3Id,
      coalesce(coalesce(_MT005CC_STD.IdL4, _MT005CC_TMP.IdL4), coalesce(_MT005PC_STD.IdL4, _MT005PC_TMP.IdL4))                                         as PandLL4Id,
      coalesce(coalesce(_MT005CC_STD.IdL5, _MT005CC_TMP.IdL5), coalesce(_MT005PC_STD.IdL5, _MT005PC_TMP.IdL5))                                         as PandLL5Id,
      coalesce(coalesce(_MT005CC_STD.L0, _MT005CC_TMP.L0), coalesce(_MT005PC_STD.L0, _MT005PC_TMP.L0))                                                 as PandLL0Name,
      coalesce(coalesce(_MT005CC_STD.L1, _MT005CC_TMP.L1), coalesce(_MT005PC_STD.L1, _MT005PC_TMP.L1))                                                 as PandLL1Name,
      coalesce(coalesce(_MT005CC_STD.L2, _MT005CC_TMP.L2), coalesce(_MT005PC_STD.L2, _MT005PC_TMP.L2))                                                 as PandLL2Name,
      coalesce(coalesce(_MT005CC_STD.L3, _MT005CC_TMP.L3), coalesce(_MT005PC_STD.L3, _MT005PC_TMP.L3))                                                 as PandLL3Name,
      coalesce(coalesce(_MT005CC_STD.L4, _MT005CC_TMP.L4), coalesce(_MT005PC_STD.L4, _MT005PC_TMP.L4))                                                 as PandLL4Name,
      coalesce(coalesce(_MT005CC_STD.L5, _MT005CC_TMP.L5), coalesce(_MT005PC_STD.L5, _MT005PC_TMP.L5))                                                 as PandLL5Name,
      /* Associations */
      _CCAllocationParentNode,
      _CCAllocationHierarchyNode,
      _CCConsolidationHierarchyNode,
      _CCConsolidationParentNode,
      _GLAccountHierarchyNode,
      _GLAccountParentNode,
      _IntercoCompanyCode,
      _PCConsolidationHierarchyNode,
      _PCConsolidationParentNode,
      _PCHierarchyFlat,
      _CCStdHierarchyNode,
      _CCStdParentNode,
      _CurrentCostCenter,
      _CurrentProfitCenter,
/* ELIMINADO DS4K9B5URA: _MT005 → _MT005CC, _MT005PC
      _MT005,
*/
/* ELIMINADO (fix performance): _MT005CC, _MT005PC
      _MT005CC,
      _MT005PC,
*/
/* AGREGADO (fix performance) */
      _MT005CC_STD,
      _MT005CC_TMP,
      _MT005PC_STD,
      _MT005PC_TMP,
      _CurrentBasisItem,
      _CCStdGrandParentNode

}
