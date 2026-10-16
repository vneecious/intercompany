@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany / Basis: ZC_IntercoJEItemClass bgresult'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoJEItemClassBGResult
  as select from zint_a_jei
  association to ZI_IntercoJEItemClassBG as _Header on  _Header.Companycode  = $projection.Companycode
                                                    and _Header.Fiscalyear   = $projection.Fiscalyear
                                                    and _Header.Fiscalperiod = $projection.Fiscalperiod
                                                    and _Header.Ledger       = $projection.Ledger
                                                    and _Header.PaymentType  = $projection.PaymentType
{
  key id                             as ID,
  key companycode                    as Companycode,
  key fiscalyear                     as Fiscalyear,
  key accountingdocument             as Accountingdocument,
  key ledgergllineitem               as Ledgergllineitem,
      fiscalperiod                   as Fiscalperiod,
      ledger                         as Ledger,
      paymenttype                    as PaymentType,
      sourceledger                   as Sourceledger,
      glaccount                      as Glaccount,
      chartofaccounts                as Chartofaccounts,
      segment                        as Segment,
      accountingdocumenttype         as Accountingdocumenttype,
      accountingdocumentitem         as Accountingdocumentitem,
      postingdate                    as Postingdate,
      debitcreditcode                as Debitcreditcode,
      accountingdocumentcategory     as Accountingdocumentcategory,
      ledgerfiscalyear               as Ledgerfiscalyear,
      creationdatetime               as Creationdatetime,
      clearingaccountingdocument     as Clearingaccountingdocument,
      clearingjournalentry           as Clearingjournalentry,
      controllingarea                as Controllingarea,
      clearingdate                   as Clearingdate,
      clearingdocfiscalyear          as Clearingdocfiscalyear,
      clearingjournalentryfiscalyear as Clearingjournalentryfiscalyear,
      isopenitemmanaged              as Isopenitemmanaged,
      transactioncurrency            as Transactioncurrency,
      @Semantics.amount.currencyCode: 'Transactioncurrency'
      amountintransactioncurrency    as Amountintransactioncurrency,
      companycodecurrency            as Companycodecurrency,
      @Semantics.amount.currencyCode: 'Companycodecurrency'
      amountincompanycodecurrency    as Amountincompanycodecurrency,
      globalcurrency                 as Globalcurrency,
      @Semantics.amount.currencyCode: 'Globalcurrency'
      amountinglobalcurrency         as Amountinglobalcurrency,
      costcenter                     as Costcenter,
      profitcenter                   as Profitcenter,
      creationdate                   as Creationdate,
      fiscalyearperiod               as Fiscalyearperiod,
      pandll0id                      as Pandll0id,
      pandll0name                    as Pandll0name,
      pandll1id                      as Pandll1id,
      pandll1name                    as Pandll1name,
      pandll2id                      as Pandll2id,
      pandll2name                    as Pandll2name,
      pandll3id                      as Pandll3id,
      pandll3name                    as Pandll3name,
      pandll4id                      as Pandll4id,
      pandll4name                    as Pandll4name,
      pandll5id                      as Pandll5id,
      pandll5name                    as Pandll5name,
      costcenterstandardhierarea     as Costcenterstandardhierarea,
      campana                        as Campana,
      area                           as Area,
      ccallocation                   as Ccallocation,
      ccconsolidation                as Ccconsolidation,
      pcconsolidation                as Pcconsolidation,
      department                     as Department,
      departmentname                 as Departmentname,
      ruleid                         as Ruleid,
      rulename                       as Rulename,
      isnotbillablefrommasterdata    as Isnotbillablefrommasterdata,
      concept                        as Concept,
      conceptname                    as Conceptname,
      classificationexemptionid      as Classificationexemptionid,
      classificationexemptionextid   as Classificationexemptionextid,
      isnotbillablefromexemption     as Isnotbillablefromexemption,
      isbillable                     as Isbillable,
      isbillablefilter               as Isbillablefilter,
      isbillabletext                 as Isbillabletext,
      isbillablecriticality          as Isbillablecriticality,
      idbase                         as Idbase,
      descriptionbase                as Descriptionbase,
      isdelta                        as Isdelta,
      indexcompanycode               as Indexcompanycode,
      indexallocation                as Indexallocation,
      indexconsolidation             as Indexconsolidation,
      area_2                         as area_2,
      indexbusinessunit              as Indexbusinessunit,
      indexpyl0                      as Indexpyl0,
      indexpyl1                      as Indexpyl1,
      indexpylclasificado            as Indexpylclasificado,
      indexcostcenter                as Indexcostcenter,
      indexaccountnro                as Indexaccountnro,
      indexmonth                     as Indexmonth,
      @Semantics.amount.currencyCode: 'Globalcurrency'
      indextotal                     as Indextotal,
      indexfacturacion               as Indexfacturacion,
      _Header
}
