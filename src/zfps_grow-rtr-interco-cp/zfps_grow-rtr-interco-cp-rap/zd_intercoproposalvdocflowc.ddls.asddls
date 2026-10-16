@EndUserText.label: 'Intercompany: Calculatiom Proposal - Visual Doc Flow Categ'
define abstract entity ZD_IntercoProposalVDocFlowC
{
  TypeID   : abap.string;
  TypeName : abap.string;
  Pos      : abap.int4;
  Icon     : abap.string;
  _Parent  : association to parent ZD_IntercoProposalVDocFlow;
}
