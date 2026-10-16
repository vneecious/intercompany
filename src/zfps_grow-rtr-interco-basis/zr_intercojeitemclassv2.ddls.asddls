/**
 * Main Interco Basis View
 *
 */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany / Basis: Journal Entry Item Clasification'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define root view entity ZR_IntercoJEItemClassV2
  as select from    I_JournalEntryItem
    inner join      ZI_IntercoCompanyCode          as _intercocompanycode           on _intercocompanycode.CompanyCode = I_JournalEntryItem.CompanyCode
    inner join      I_CostCenter                   as _currentcostcenter            on  I_JournalEntryItem.ControllingArea   = _currentcostcenter.ControllingArea
                                                                                    and I_JournalEntryItem.CostCenter        = _currentcostcenter.CostCenter
                                                                                    and _currentcostcenter.ValidityStartDate <= $session.system_date
                                                                                    and _currentcostcenter.ValidityEndDate   >= $session.system_date

  // CC ALLOC
    inner join I_CostCenterHierarchyNode      as _ccallocationhierarchynode    on  _ccallocationhierarchynode.CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
                                                                                    and _ccallocationhierarchynode.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                                    and _ccallocationhierarchynode.CostCenter          = I_JournalEntryItem.CostCenter
//                                                                                    and I_JournalEntryItem.CostCenter                  is not initial
    inner join I_CostCenterHierarchyNode      as _ccallocationparentnode       on  _ccallocationparentnode.CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
                                                                                    and _ccallocationparentnode.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                                    and _ccallocationparentnode.HierarchyNode       = _ccallocationhierarchynode.ParentNode
//                                                                                    and I_JournalEntryItem.CostCenter               is not initial
  // CC CONS
    left outer join I_CostCenterHierarchyNode      as _ccconsolidationhierarchynode on  _ccconsolidationhierarchynode.CostCenterHierarchy = 'H101/ML00/CONS_CC'
                                                                                    and _ccconsolidationhierarchynode.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                                    and _ccconsolidationhierarchynode.CostCenter          = I_JournalEntryItem.CostCenter
                                                                                    and I_JournalEntryItem.CostCenter                     is not initial
    left outer join I_CostCenterHierarchyNode      as _ccconsolidationparentnode    on  _ccconsolidationparentnode.CostCenterHierarchy = 'H101/ML00/CONS_CC'
                                                                                    and _ccconsolidationparentnode.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                                    and _ccconsolidationparentnode.HierarchyNode       = _ccconsolidationhierarchynode.ParentNode
                                                                                    and I_JournalEntryItem.CostCenter                  is not initial

  // CC Standard
    inner join I_CostCenterHierarchyNode      as _ccstdhierarchynode           on  _ccstdhierarchynode.CostCenterHierarchy = '0101/ML00/ML00'
                                                                                    and _ccstdhierarchynode.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                                    and _ccstdhierarchynode.CostCenter          = I_JournalEntryItem.CostCenter
//                                                                                    and I_JournalEntryItem.CostCenter           is not initial
    inner join I_CostCenterHierarchyNode      as _ccstdparentnode              on  _ccstdparentnode.CostCenterHierarchy = '0101/ML00/ML00'
                                                                                    and _ccstdparentnode.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                                    and _ccstdparentnode.HierarchyNode       = _ccstdhierarchynode.ParentNode
//                                                                                    and I_JournalEntryItem.CostCenter        is not initial

  // PC CONS
    left outer join I_ProfitCenterHierarchyNode    as _pcconsolidationhierarchynode on  _pcconsolidationhierarchynode.ProfitCenterHierarchy = 'H106/ML00/CONS_PC'
                                                                                    and _pcconsolidationhierarchynode.ControllingArea       = I_JournalEntryItem.ControllingArea
                                                                                    and _pcconsolidationhierarchynode.ProfitCenter          = I_JournalEntryItem.ProfitCenter
                                                                                    and I_JournalEntryItem.ProfitCenter                     is not initial
    left outer join I_ProfitCenterHierarchyNode    as _pcconsolidationparentnode    on  _pcconsolidationparentnode.ProfitCenterHierarchy = 'H106/ML00/CONS_PC'
                                                                                    and _pcconsolidationparentnode.ControllingArea       = I_JournalEntryItem.ControllingArea
                                                                                    and _pcconsolidationparentnode.HierarchyNode         = _pcconsolidationhierarchynode.ParentNode
                                                                                    and I_JournalEntryItem.ProfitCenter                  is not initial


  // ZBCE
    left outer join I_GLAccountHierarchyNode       as _glaccounthierarchynode       on  _glaccounthierarchynode.GLAccountHierarchy = 'H109/MLIB/ZBCE'
                                                                                    and _glaccounthierarchynode.ChartOfAccounts    = I_JournalEntryItem.ChartOfAccounts
                                                                                    and _glaccounthierarchynode.GLAccount          = I_JournalEntryItem.GLAccount
    left outer join I_GLAccountHierarchyNode       as _glaccountparentnode          on  _glaccountparentnode.GLAccountHierarchy = 'H109/MLIB/ZBCE'
                                                                                    and _glaccountparentnode.ChartOfAccounts    = I_JournalEntryItem.ChartOfAccounts
                                                                                    and _glaccountparentnode.HierarchyNode      = _glaccounthierarchynode.ParentNode
  // PC Standard
    left outer join ZI_ProfitCenterHierarchyFlat   as _pchierarchyflat              on  _pchierarchyflat.ControllingArea =  I_JournalEntryItem.ControllingArea
                                                                                    and _pchierarchyflat.ProfitCenter    =  I_JournalEntryItem.ProfitCenter
                                                                                    and _pchierarchyflat.ValidityEndDate >= I_JournalEntryItem.PostingDate
    left outer join ZI_IntercoBasisItem            as _currentbasisitem             on  _currentbasisitem.Ledger              =       I_JournalEntryItem.Ledger
                                                                                    and _currentbasisitem.Glaccount           =       I_JournalEntryItem.GLAccount
                                                                                    and _currentbasisitem.Costcenter          =       I_JournalEntryItem.CostCenter
                                                                                    and _currentbasisitem.Fiscalyear          =       I_JournalEntryItem.FiscalYear
                                                                                    and _currentbasisitem.Fiscalperiod        =       I_JournalEntryItem.FiscalPeriod
                                                                                    and _currentbasisitem.Providercompanycode =       I_JournalEntryItem.CompanyCode
                                                                                    and _currentbasisitem.Profitcenter        =       I_JournalEntryItem.ProfitCenter
                                                                                    and I_JournalEntryItem.CreationDateTime   between _currentbasisitem.MinDateTime and _currentbasisitem.MaxDateTime
                                                                                    and _currentbasisitem.ExecutionStatus     =       'COMPLETED'
  // MT005 (P&L)
    left outer join Z_PNL_MT005                    as _mt005CC                      on  ( _mt005CC.zagrup_cuentas                     = _glaccountparentnode.HierarchyNode 
                                                                                          or _mt005CC.temp_zagrup_cuentas =  _glaccountparentnode.HierarchyNode )
                                                                                    and _ccconsolidationparentnode.HierarchyNode is not null
                                                                                    and _mt005CC.zconsolidation                     = _ccconsolidationparentnode.HierarchyNode
    left outer join Z_PNL_MT005                    as _mt005PC                      on  ( _mt005PC.zagrup_cuentas                     = _glaccountparentnode.HierarchyNode
                                                                                        or _mt005PC.temp_zagrup_cuentas =  _glaccountparentnode.HierarchyNode )
                                                                                    and _ccconsolidationparentnode.HierarchyNode is null
                                                                                    and _mt005PC.zconsolidation                     = _pcconsolidationparentnode.HierarchyNode

  // Classifications
    left outer join ZR_IntercoJEItemHelperClassItm as _classificationsCC            on  _classificationsCC.Ledger                     = I_JournalEntryItem.Ledger
                                                                                    and _classificationsCC.CompanyCode                = I_JournalEntryItem.CompanyCode
                                                                                    and _classificationsCC.FiscalYear                 = I_JournalEntryItem.FiscalYear
                                                                                    and _classificationsCC.FiscalPeriod               = I_JournalEntryItem.FiscalPeriod
                                                                                    -- Ini Facturación Local CH/ARG EXT_OSCUGALD 05.10.2026 - C06: quitar filtro fijo E para permitir clasificación E/L
                                                                                    -- and _classificationsCC.PaymentType                = 'E'
                                                                                    -- Fin EXT_OSCUGALD 05.10.2026 - C06
                                                                                    and _classificationsCC.PandLL5ID                  = _mt005CC.IdL5
                                                                                    and _classificationsCC.CcConsolidation            = _ccconsolidationparentnode.HierarchyNodeVal
                                                                                    and _classificationsCC.CostCenterStandardHierArea = _currentcostcenter.CostCenterStandardHierArea
                                                                                    and _classificationsCC.CcAllocation               = _ccallocationparentnode.HierarchyNodeVal
                                                                                    and _classificationsCC.ProfitCenter               = I_JournalEntryItem.ProfitCenter

    left outer join ZR_IntercoJEItemHelperClassItm as _classificationsPC            on  _classificationsPC.Ledger                     = I_JournalEntryItem.Ledger
                                                                                    and _classificationsPC.CompanyCode                = I_JournalEntryItem.CompanyCode
                                                                                    and _classificationsPC.FiscalYear                 = I_JournalEntryItem.FiscalYear
                                                                                    and _classificationsPC.FiscalPeriod               = I_JournalEntryItem.FiscalPeriod
                                                                                    -- Ini Facturación Local CH/ARG EXT_OSCUGALD 05.10.2026 - C06: quitar filtro fijo E para permitir clasificación E/L
                                                                                    -- and _classificationsPC.PaymentType                = 'E'
                                                                                    -- Fin EXT_OSCUGALD 05.10.2026 - C06
                                                                                    and _classificationsPC.PandLL5ID                  = _mt005PC.IdL5
                                                                                    and _classificationsPC.CcConsolidation            = _ccconsolidationparentnode.HierarchyNodeVal
                                                                                    and _classificationsPC.CostCenterStandardHierArea = _currentcostcenter.CostCenterStandardHierArea
                                                                                    and _classificationsCC.CcAllocation               = _ccallocationparentnode.HierarchyNodeVal
                                                                                    and _classificationsPC.ProfitCenter               = I_JournalEntryItem.ProfitCenter


    left outer join ZI_IntercoClassificationRule   as _classificationruleCC         on _classificationsCC.RuleID = _classificationruleCC.RuleID

    left outer join ZI_IntercoClassificationRule   as _classificationrulePC         on _classificationsPC.RuleID = _classificationrulePC.RuleID

// Exemptions
    left outer join ZR_INTERCOJEITEMHELPERCLASSEXE as _exemptions                   on  _exemptions.Ledger       = I_JournalEntryItem.Ledger
                                                                                    and _exemptions.CompanyCode  = I_JournalEntryItem.CompanyCode
                                                                                    and _exemptions.FiscalYear   = I_JournalEntryItem.FiscalYear
                                                                                    and _exemptions.FiscalPeriod = I_JournalEntryItem.FiscalPeriod
                                                                                    -- Ini Facturación Local CH/ARG EXT_OSCUGALD 05.10.2026 - C06: quitar filtro fijo E para permitir exclusiones E/L
                                                                                    -- and _exemptions.PaymentType  = 'E'
                                                                                    -- Fin EXT_OSCUGALD 05.10.2026 - C06
                                                                                    and _exemptions.CostCenter   = I_JournalEntryItem.CostCenter
                                                                                    and _exemptions.GLAccount    = I_JournalEntryItem.GLAccount
                                                                                    and _exemptions.ProfitCenter = I_JournalEntryItem.ProfitCenter
    -- Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12m (7a): exclusión por tipo resuelto en origen 02
    and (
      I_JournalEntryItem.OriginObjectType <> '02'
      or (
        I_JournalEntryItem.OriginObjectType = '02'
        and (
          (
            _ccconsolidationparentnode.HierarchyNodeVal is not null
            and (
              ( _classificationsCC.PaymentType = 'L'
                and _exemptions.PaymentType = 'L' )
              or (
                ( _classificationsCC.PaymentType is null
                  or _classificationsCC.PaymentType <> 'L' )
                and _exemptions.PaymentType = 'E'
              )
            )
          )
          or (
            _ccconsolidationparentnode.HierarchyNodeVal is null
            and (
              ( _classificationsPC.PaymentType = 'L'
                and _exemptions.PaymentType = 'L' )
              or (
                ( _classificationsPC.PaymentType is null
                  or _classificationsPC.PaymentType <> 'L' )
                and _exemptions.PaymentType = 'E'
              )
            )
          )
        )
      )
    )
    -- Fin EXT_OSCUGALD 07.10.2026 - C12m (7a)                                                                                    
    left outer join ZI_IntercoDepartmentRule       as _departmentruleCC             on  _departmentruleCC.CompanyCode  = I_JournalEntryItem.CompanyCode
                                                                                    and _departmentruleCC.PAndLId      = _mt005CC.IdL3
                                                                                    and _departmentruleCC.Product      = _classificationruleCC.Product
    left outer join ZI_IntercoDepartmentRule       as _departmentrulePC             on  _departmentrulePC.CompanyCode  = I_JournalEntryItem.CompanyCode
                                                                                    and _departmentrulePC.PAndLId      = _mt005PC.IdL3
                                                                                    and _departmentrulePC.Product      = _classificationrulePC.Product
                                                                                    and _departmentrulePC.ProfitCenter is initial
{
  key I_JournalEntryItem.SourceLedger,
  key I_JournalEntryItem.CompanyCode,
  key I_JournalEntryItem.FiscalYear,
  key I_JournalEntryItem.AccountingDocument,
  key I_JournalEntryItem.LedgerGLLineItem,
  key I_JournalEntryItem.Ledger,
  key I_JournalEntryItem.FiscalPeriod,
      I_JournalEntryItem.Segment,
      I_JournalEntryItem.AccountingDocumentType,
      I_JournalEntryItem.AccountingDocumentItem,
      I_JournalEntryItem.DebitCreditCode,
      I_JournalEntryItem.AccountingDocumentCategory,
      I_JournalEntryItem.LedgerFiscalYear,
      I_JournalEntryItem.ClearingAccountingDocument,
      I_JournalEntryItem.ClearingJournalEntry,
      I_JournalEntryItem.ClearingDate,
      I_JournalEntryItem.ClearingDocFiscalYear,
      I_JournalEntryItem.ClearingJournalEntryFiscalYear,
      I_JournalEntryItem.IsOpenItemManaged,
      I_JournalEntryItem.TransactionCurrency,
      I_JournalEntryItem.AmountInTransactionCurrency,
      I_JournalEntryItem.CompanyCodeCurrency,
      I_JournalEntryItem.AmountInCompanyCodeCurrency,
      I_JournalEntryItem.GlobalCurrency,
      I_JournalEntryItem.AmountInGlobalCurrency,
      I_JournalEntryItem.CreationDate,
      I_JournalEntryItem.FiscalYearPeriod,
      I_JournalEntryItem.OriginObjectType,
      I_JournalEntryItem.GLAccount,
      I_JournalEntryItem.ChartOfAccounts,
      I_JournalEntryItem.PostingDate,
      I_JournalEntryItem.CreationDateTime,
      I_JournalEntryItem.ControllingArea,
      I_JournalEntryItem.CostCenter,
      I_JournalEntryItem.ProfitCenter,
      // Intercompany Specifics
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 05.10.2026 - C06: liberar el valor I; el tipo definitivo se asigna por regla
      -- case I_JournalEntryItem.OriginObjectType when '02' then 'E' else 'I' end                      as PaymentType,
      -- case I_JournalEntryItem.OriginObjectType when '02' then 'E' else '' end                       as PaymentType,
      -- Fin EXT_OSCUGALD 05.10.2026 - C06

      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12m (7a): tipo resuelto de la rama CC/PC
      cast(
        case
          when I_JournalEntryItem.OriginObjectType = '02'
               and _ccconsolidationparentnode.HierarchyNodeVal is not null
               and _classificationsCC.PaymentType = 'L'
            then _classificationsCC.PaymentType
          when I_JournalEntryItem.OriginObjectType = '02'
               and _ccconsolidationparentnode.HierarchyNodeVal is null
               and _classificationsPC.PaymentType = 'L'
            then _classificationsPC.PaymentType
          else
            case I_JournalEntryItem.OriginObjectType
              when '02' then 'E'
              else ''
            end
        end
        as zint_dte_paymenttype preserving type
      ) as PaymentType,
      -- Fin EXT_OSCUGALD 07.10.2026 - C12m (7a)
      
      _intercocompanycode.SiteCode,
      _intercocompanycode.SiteName,
      _currentcostcenter.CostCenterStandardHierArea,
      _glaccountparentnode.HierarchyNode                                                         as GLAccountParentNode,
      _ccconsolidationparentnode.HierarchyNodeVal                                                   as CCConsolidation,
      _pcconsolidationparentnode.HierarchyNodeVal                                                   as PCConsolidation,
      _ccallocationparentnode.HierarchyNodeVal                                                      as CCAllocation,

      // P&L
      case
      when _ccconsolidationparentnode.HierarchyNodeVal is not null
       then _mt005CC.zagrup_cuentas
      else _mt005PC.zagrup_cuentas
      end                                                                                           as zagrup_cuentas,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.zconsolidation
        else _mt005PC.zconsolidation
      end                                                                                           as zconsolidation,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.IdL0
        else _mt005PC.IdL0
      end                                                                                           as PandLL0Id,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.L0
        else _mt005PC.L0
      end                                                                                           as PandLL0Name,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.IdL1
        else _mt005PC.IdL1
      end                                                                                           as PandLL1Id,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.L1
        else _mt005PC.L1
      end                                                                                           as PandLL1Name,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.IdL2
        else _mt005PC.IdL2
      end                                                                                           as PandLL2Id,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.L2
        else _mt005PC.L2
      end                                                                                           as PandLL2Name,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.IdL3
        else _mt005PC.IdL3
      end                                                                                           as PandLL3Id,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.L3
        else _mt005PC.L3
      end                                                                                           as PandLL3Name,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.IdL4
        else _mt005PC.IdL4
      end                                                                                           as PandLL4Id,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.L4
        else _mt005PC.L4
      end                                                                                           as PandLL4Name,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.IdL5
        else _mt005PC.IdL5
      end                                                                                           as PandLL5Id,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _mt005CC.L5
        else _mt005PC.L5
      end                                                                                           as PandLL5Name,

      // Classification Rule
      case
      when _ccconsolidationparentnode.HierarchyNodeVal is not null
       then _classificationruleCC.ID
      else _classificationrulePC.ID
      end                                                                                           as ClassificationRuleID,

      cast(
        case
          when _ccconsolidationparentnode.HierarchyNodeVal is not null
               then coalesce( _classificationsCC.RuleID, '0000000000' )
          else coalesce( _classificationsPC.RuleID, '0000000000' )
        end
        as zint_rule_id
      )                                                                                             as ClassificationRuleExtID,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _classificationruleCC.RuleName
        else _classificationrulePC.RuleName
      end                                                                                           as RuleName,
     

      case
        when _currentbasisitem.Id is not null
          then cast( coalesce( _currentbasisitem.Product, '--' ) as matnr )
        else
          case $projection.IsBillable
            when 'E' then '--'
            else
              cast(
                coalesce(
                  coalesce( _classificationruleCC.Product, _classificationrulePC.Product ),
                  '--'
                ) as matnr
              )
          end
      end as Concept,


      case
        when $projection.DescriptionBase = '' or $projection.DescriptionBase is null
        then
          case $projection.IsBillable
            when 'E' then ''
            else
              case
                when _ccconsolidationparentnode.HierarchyNodeVal is not null
                     then _classificationruleCC._Product.ProductName
                else _classificationrulePC._Product.ProductName
              end
          end
        else
          _currentbasisitem._Product.ProductName
      end                                                                                           as ConceptName,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _classificationruleCC.IsNotBillable
        else _classificationrulePC.IsNotBillable
      end                                                                                           as IsNotBillableFromMasterData,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _classificationruleCC.Score
        else _classificationrulePC.Score
      end                                                                                           as ClassificationRuleScore,


      // Exemption
      _exemptions._ExemptionRule.ID                                                                 as ClassificationExemptionID,
      cast(coalesce(_exemptions.ExemptionID, '0000000000' ) as zint_exemption_id)                   as ClassificationExemptionExtID,
      _exemptions._ExemptionRule.ExemptionName,
      cast( case when _exemptions.ExemptionID is not initial then 'X' else '' end as abap_boolean ) as IsNotBillableFromExemption,

      // Is Billable
      cast(
        case
      -- 1) Exemption
          when _exemptions.ExemptionID is not initial
            then 'E'

      -- 2) No Tratado
            when _classificationsCC.RuleID is null and _classificationsPC.RuleID is null
            then '-
            '
      -- 3) No Faturable
          when
            case
              when _ccconsolidationparentnode.HierarchyNodeVal is not null
                   then _classificationruleCC.IsNotBillable
              else _classificationrulePC.IsNotBillable
            end
            = 'X'
            then 'N'
      -- 4) Facturable
          else 'B'
        end
        as zint_billable_status
      )                                                                                             as IsBillable,



      case $projection.IsBillable
           when 'B' then 3
           when 'N' then 1
           when 'E' then 2
           else 0 end                                                                               as IsBillableCriticality,
      _currentbasisitem.Id                                                                          as IdBase,
      _currentbasisitem._header.Description                                                         as DescriptionBase,
      _currentbasisitem._header.IsReleased                                                          as IsReleased,
      _currentbasisitem._header.CompanyCode                                                         as CurrentBasis_CompanyCode,
      _currentbasisitem._header.Ledger                                                              as CurrentBasis_Ledger,
      _currentbasisitem._header.FiscalYear                                                          as CurrentBasis_FiscalYear,
      _currentbasisitem._header.FiscalPeriod                                                        as CurrentBasis_FiscalPeriod,
      _currentbasisitem._header.PaymentType                                                         as CurrentBasis_PaymentType,
      _currentbasisitem.Department                                                                  as CurrentBasis_Department,
      _currentbasisitem._Department.Description                                                     as CurrentBasis_DepartmentDescr,
      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _departmentruleCC.Department
        else _departmentrulePC.Department
      end                                                                                           as departmentrule_Department,

      case
        when _ccconsolidationparentnode.HierarchyNodeVal is not null
             then _departmentruleCC._Department.Description
        else _departmentrulePC._Department.Description
      end                                                                                           as departmentrule_description,

      // TEMP INDEX ->
      I_JournalEntryItem.CompanyCode                                                                as IndexCompanyCode,
      _ccallocationparentnode._Text[ 1: Language = $session.system_language ].HierarchyNodeText     as IndexAllocation,
      _ccconsolidationparentnode._Text[ 1: Language = $session.system_language ].HierarchyNodeText  as IndexConsolidation,
      _ccstdparentnode._Text[1: Language = $session.system_language ].HierarchyNodeText             as IndexArea,
      _pchierarchyflat._BusinessUnitText[1: Language = $session.system_language ].HierarchyNodeText as IndexBusinessUnit,
      $projection.PandLL0Name                                                                       as IndexPYL0,
      $projection.PandLL1Name                                                                       as IndexPYL1,
      $projection.PandLL2Name                                                                       as IndexPYLCLASIFICADO,
      I_JournalEntryItem.CostCenter                                                                 as IndexCostCenter,
      I_JournalEntryItem.GLAccount                                                                  as IndexAccountNro,
      concat(I_JournalEntryItem.FiscalYear, substring(I_JournalEntryItem.FiscalPeriod, 2, 2))       as IndexMonth,
      I_JournalEntryItem.AmountInGlobalCurrency                                                     as IndexTotal,
      $projection.ConceptName                                                                       as IndexFacturacion
      // TEMP INDEX <-
}
where
  (
       I_JournalEntryItem.GLAccountType    = 'P'
    or I_JournalEntryItem.GLAccountType    = 'N'
    or I_JournalEntryItem.GLAccountType    = 'S'
  )
  and(
       I_JournalEntryItem.OriginObjectType = '01'
    or I_JournalEntryItem.OriginObjectType = '02'
    or I_JournalEntryItem.OriginObjectType = '45'
  )
// fijando el P&L (26/12/2025) // Eliminado pues el usuario lo enviara desde el frontend siempre (31/7/2026)
//  and (
//      ( _ccconsolidationparentnode.HierarchyNodeVal is not null
//        and ( _mt005CC.IdL0 = '0PL_L0_02'
//           or _mt005CC.IdL0 = '0PL_L0_03'
//           or ( _mt005CC.IdL0 = '0PL_L0_06' and I_JournalEntryItem.CompanyCode = 'MLB' ) ) //DF-474 EXT_OSCUGALD
//      )
//   or ( _ccconsolidationparentnode.HierarchyNodeVal is null
//        and ( _mt005PC.IdL0 = '0PL_L0_02'
//           or _mt005PC.IdL0 = '0PL_L0_03'
//           or ( _mt005PC.IdL0 = '0PL_L0_06' and I_JournalEntryItem.CompanyCode = 'MLB' ) ) //DF-474 EXT_OSCUGALD
//      )
//  )
  // fijando el CC Allocation (29/12/2025)
  //  and _ccallocationparentnode.HierarchyNodeVal = '20' 
  // CC Allocation
  and _ccallocationparentnode.HierarchyNodeVal is not initial 


