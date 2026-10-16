@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany CeBe''s equivalentes'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_INTERCOCEBE
  //with parameters
  //@EndUserText.label: 'ID Jerarquía'
  //p_ver_id: vrsid
  as select from uhdt_node as _Node
  association [0..1] to uhdt_node as _NodeParent on _Node.node_pid = _NodeParent.node_id
  association [1..1] to uhdt_vrsn as _Version on _Node.ver_id = _Version.ver_id
{
  key _Node.ver_id,
  key _Node.node_id,
      ltrim(_Node.node_lval,'0')       as ProfitCenter,
      case
      when _Node.node_level > '000001' then cast ( 'X' as boole_d )
      else cast ( '' as boole_d )
      end                   as IsChild,
      _Node.node_pid,
      ltrim(_NodeParent.node_lval,'0') as ParentProfitCenter

}
where _Version.hier_hid = 'ZICEQ'
  and _Version.hier_catg = '0106'
  and _Node.node_level > '000000'
//_Node.ver_id = $parameters.p_ver_id //'42010A5501221FD084FCAD100C75583C'
