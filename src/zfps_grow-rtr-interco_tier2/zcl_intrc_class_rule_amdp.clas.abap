class zcl_intrc_class_rule_amdp definition
  public
  final
  create public .

  public section.

    interfaces if_amdp_marker_hdb.

    class-methods get_overlaps for table function ZTF_IntercoClassRuleOverlap.
  protected section.
  private section.
endclass.



class zcl_intrc_class_rule_amdp implementation.

  method get_overlaps
    by database function for hdb
    language sqlscript
    options read-only
    using zint_a_md_cr cepc zint_a_md001 hrrp_node_n z_v_pnl_mt005.

    declare lv_companycode "$ABAP.type( zint_a_md_cr-company_code )";
    declare lv_profitcenter "$ABAP.type( zint_a_md_cr-profit_center )";
    declare lv_cc_allocation "$ABAP.type( zint_a_md_cr-cc_allocation )";
    declare lv_cc_consolidation "$ABAP.type( zint_a_md_cr-cc_consolidation )";
    declare lv_cc_std_hier_area "$ABAP.type( zint_a_md_cr-cc_std_hier_area )";
    declare lv_valid_from "$ABAP.type( zint_a_md_cr-valid_from )";
    declare lv_valid_to "$ABAP.type( zint_a_md_cr-valid_to )";
    declare lv_p_and_l_id "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_p_and_l_id_5 "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_p_and_l_id_4 "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_p_and_l_id_3 "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_p_and_l_id_2 "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_p_and_l_id_1 "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_p_and_l_id_0 "$ABAP.type( zint_a_md_cr-p_and_l_id )";
    declare lv_score "$ABAP.type( i )";

    declare lt_out table( client "$ABAP.type( mandt )",
                          rule_id "$ABAP.type( zint_rule_id )",
                          rule_name "$ABAP.type( zint_rule_name )",
                          valid_from "$ABAP.type( zvalid_from )",
                          valid_to "$ABAP.type( zvalid_to )",
                          error "$ABAP.type( char256 )" );

        current_rule = select rules.*,
                              case when rules.company_code = '' then 0 else 1 end +
                              case when rules.profit_center = '' then 0 else 1 end +
                              case when rules.p_and_l_id = '' then 0 else 1 end +
                              case when rules.cc_allocation = '' then 0 else 1 end +
                              case when rules.cc_consolidation = '' then 0 else 1 end +
                              case when rules.cc_std_hier_area = '' then 0 else 1 end as score
                              from zint_a_md_cr as rules
            where client = iv_client
            and rule_id = iv_rule_id
            and rules.is_deleted = '';

        if ::rowcount = 0 then
            lt_out.client[1] := :iv_client;
            lt_out.error[1] := 'INVALID_RULE_ID';
            return :lt_out;
        end if;

        lv_companycode := :current_rule.company_code[1];
        lv_profitcenter := :current_rule.profit_center[1];
        lv_cc_allocation := :current_rule.cc_allocation[1];
        lv_cc_consolidation := :current_rule.cc_consolidation[1];
        lv_cc_std_hier_area := :current_rule.cc_std_hier_area[1];
        lv_p_and_l_id := :current_rule.p_and_l_id[1];
        lv_valid_from := :current_rule.valid_from[1];
        lv_valid_to := :current_rule.valid_to[1];
        lv_score := :current_rule.score[1];

        spread_pandls = select distinct idl5, idl4, idl3, idl2, idl1, idl0
            from z_v_pnl_mt005
                where mandt = iv_client and
                   ( idl5 = :lv_p_and_l_id
                   or idl4 = :lv_p_and_l_id
                   or idl3 = :lv_p_and_l_id
                   or idl2 = :lv_p_and_l_id
                   or idl1 = :lv_p_and_l_id
                   or idl0 = :lv_p_and_l_id );
        if ::rowcount > 0 then
            lv_p_and_l_id_5 := :spread_pandls.idl5[1];
            lv_p_and_l_id_4 := :spread_pandls.idl4[1];
            lv_p_and_l_id_3 := :spread_pandls.idl3[1];
            lv_p_and_l_id_2 := :spread_pandls.idl2[1];
            lv_p_and_l_id_1 := :spread_pandls.idl1[1];
            lv_p_and_l_id_0 := :spread_pandls.idl0[1];

            p_and_l_ids = select p_and_l_id from (
                select :lv_p_and_l_id_5 as p_and_l_id from dummy
                union all
                select :lv_p_and_l_id_4 as p_and_l_id from dummy
                union all
                select :lv_p_and_l_id_3 as p_and_l_id from dummy
                union all
                select :lv_p_and_l_id_2 as p_and_l_id from dummy
                union all
                select :lv_p_and_l_id_1 as p_and_l_id from dummy
                union all
                select :lv_p_and_l_id_0 as p_and_l_id from dummy ) as p_and_l_ids;


        end if;

        if :lv_companycode = '' THEN
            company_codes = select distinct providercompanycode as company_code from zint_a_md001 where mandt = :iv_client;
        else
            company_codes.company_code[1] := lv_companycode;
        end if;

        if :lv_profitcenter = '' THEN
            profit_centers = select distinct
                    prctr as profit_center
                from cepc
                    where mandt = iv_client
                      and datbi >= :lv_valid_from
                      and datab <= :lv_valid_to;
        else
            profit_centers.profit_center[1] := lv_profitcenter;
        end if;

        if :lv_cc_allocation = '' THEN
            cc_allocations = select distinct
                 nodevalue as cc_allocation
              from hrrp_node_n
              where mandt = iv_client
                and hrytyp = '0101'
                and hryid = 'H101/ML00/ALLOC_CC'
                and nodetype = 'N';
        else
            cc_allocations.cc_allocation[1] := lv_cc_allocation;
        end if;

        if :lv_cc_consolidation = '' THEN
            cc_consolidations = select distinct
                   nodevalue as cc_consolidation
                from hrrp_node_n
                where mandt = iv_client
                  and hrytyp = '0101'
                  and hryid = 'H101/ML00/CONS_CC'
                  and nodetype = 'N';
        else
            cc_consolidations.cc_consolidation[1] := lv_cc_consolidation;
        end if;

        duplicated_rules = select distinct
                rules.client,
                rules.rule_id,
                rules.rule_name,
                rules.valid_from,
                rules.valid_to,
                case when rules.company_code = '' then 0 else 1 end +
                              case when rules.profit_center = '' then 0 else 1 end +
                              case when rules.p_and_l_id = '' then 0 else 1 end +
                              case when rules.cc_allocation = '' then 0 else 1 end +
                              case when rules.cc_consolidation = '' then 0 else 1 end +
                              case when rules.cc_std_hier_area = '' then 0 else 1 end as score
            from zint_a_md_cr as rules
            where client = iv_client
              and ( rules.company_code in (select company_code from :company_codes) or rules.company_code = '' )
              and ( rules.profit_center in (select profit_center from :profit_centers) or rules.profit_center = '' )
              and ( rules.cc_consolidation in (select cc_consolidation from :cc_consolidations) or rules.cc_consolidation = '' )
              and ( rules.cc_allocation in ( select cc_allocation from :cc_allocations ) or rules.cc_allocation = '' )
              and ( rules.cc_std_hier_area = :lv_cc_std_hier_area or rules.cc_std_hier_area = '' )
              and ( rules.p_and_l_id in ( select p_and_l_id from :p_and_l_ids ) or rules.p_and_l_id = '' )
              and is_deleted = ''
              and rule_id <> :iv_rule_id
              and valid_to >= :lv_valid_from
              and valid_from <= :lv_valid_to;

          return select client, rule_id, rule_name, valid_from, valid_to, '' as error
            from :duplicated_rules
            where score = :lv_score;

  endmethod.

endclass.
