@EndUserText.label: 'Intercompany: Classification Rule - Check for overlaps'
define table function ZTF_IntercoClassRuleOverlap
  with parameters
    @Environment.systemField: #CLIENT
    iv_client  : abap.clnt,
    iv_rule_id : zint_rule_id
returns
{
  client     : abap.clnt;
  rule_id    : zint_rule_id;
  rule_name  : zint_rule_name;
  valid_from : zvalid_from;
  valid_to   : zvalid_to;
  error      : abap.string(256);

}
implemented by method
  zcl_intrc_class_rule_amdp=>get_overlaps;
