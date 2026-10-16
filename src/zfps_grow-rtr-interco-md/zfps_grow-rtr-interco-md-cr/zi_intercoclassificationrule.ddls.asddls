@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Classification Rules for Intercompany'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #MIXED
}
define view entity ZI_IntercoClassificationRule
  as select from zint_a_md_cr
  association [0..1] to ZI_IntercoCompanyCode        as _CompanyCode  on  $projection.CompanyCode  is not initial
                                                                      and _CompanyCode.CompanyCode = $projection.CompanyCode
  association [0..*] to ZI_IntercoProfitCenter       as _ProfitCenter on  $projection.ProfitCenter   is not initial
                                                                      and _ProfitCenter.ProfitCenter = $projection.ProfitCenter
  association [0..*] to ZI_IntercoCostCenter         as _CostCenter   on  (
        $projection.CcAllocation                                                                                     is not initial
        and _CostCenter.Allocation                                                                                   = $projection.CcAllocation
      )
                                                                      or  (
                                                                          $projection.CcConsolidation                is not initial
                                                                          and _CostCenter.Consolidation              = $projection.CcConsolidation
                                                                        )
                                                                      or  (
                                                                          $projection.CcStdHierArea                  is not initial
                                                                          and _CostCenter.CostCenterStandardHierArea = $projection.CcStdHierArea
                                                                        )
  association [0..1] to ZI_IntercoPandLHierFlattened as _PandL        on  $projection.PAndLID is not initial
                                                                      and _PandL.ID           = $projection.PAndLID
  association [0..1] to ZI_IntercoProduct            as _Product      on  $projection.Product is not initial
                                                                      and _Product.Product    = $projection.Product

{

  key id                                               as ID,
      rule_id                                          as RuleID,
      rule_name                                        as RuleName,
      valid_from                                       as ValidFrom,
      valid_to                                         as ValidTo,
      company_code                                     as CompanyCode,
      ledger                                           as Ledger,
      -- AGREGADO EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C08: expone PaymentType de la regla ganadora
      payment_type                                     as PaymentType,
      -- Fin EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C08
      p_and_l_id                                       as PAndLID,
      p_and_l_level                                    as PandLLevel,
      profit_center                                    as ProfitCenter,
      cc_std_hier_area                                 as CcStdHierArea,
      cc_allocation                                    as CcAllocation,
      cc_consolidation                                 as CcConsolidation,
      product                                          as Product,
      is_not_billable                                  as IsNotBillable,
      is_deleted                                       as IsDeleted,
      cast (case
                when valid_to >= $session.user_date and
                     valid_from <= $session.user_date
                then 'X' else '' end as abap_boolean ) as IsValid,
      -- Used to determine which rule should prevail when multiple rules match.
      -- Higher scores indicate higher specificity (more fields filled), giving priority to more specific rules.
      cast(
      ( case when company_code is not initial then 1.0 else 0.0 end +
      case when profit_center is not initial then 1.0 else 0.0 end +
      case when cc_std_hier_area is not initial then 1.0 else 0.0 end +
      case when cc_allocation is not initial then 1.0 else 0.0 end +
      case when cc_consolidation is not initial then 1.0 else 0.0 end +
      ( case when p_and_l_id is not initial then 1.0 else 0.0 end *
        case p_and_l_level
          when 'L5' then 600.0
          when 'L4' then 500.0
          when 'L3' then 400.0
          when 'L2' then 300.0
          when 'L1' then 200.0
          when 'L0' then 100.0
        else
          case substring(p_and_l_id, 5, 2 )
            when 'L5' then 600.0
            when 'L4' then 500.0
            when 'L3' then 400.0
            when 'L2' then 300.0
            when 'L1' then 200.0
            when 'L0' then 100.0 
          end
          end ) ) / 605.0 * 100.0 as abap.dec( 5, 2 ) )         as Score,
      //             / 6.0 * 100.0 as abap.dec( 5, 2 ))        as Score,
      @Semantics.systemDateTime.createdAt: true
      created_at                                       as CreatedAt,
      @Semantics.user.createdBy: true
      created_by                                       as CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                                  as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at                            as LocalLastChangedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by                                  as LastChangedBy,
      _ProfitCenter,
      _CostCenter,
      _CompanyCode,
      _PandL,
      _Product
}
//group by
//  id,
//  rule_id,
//  rule_name,
//  valid_from,
//  valid_to,
//  company_code,
//  p_and_l_id,
//  p_and_l_level,
//  profit_center,
//  cc_std_hier_area,
//  cc_allocation,
//  cc_consolidation,
//  product,
//  is_not_billable,
//  created_at,
//  created_by,
//  last_changed_at,
//  local_last_changed_at,
//  last_changed_by,
//  is_deleted
