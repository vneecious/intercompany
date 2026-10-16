@EndUserText.label: 'Intercompany: Calculatiom Proposal - Visual Document Flow'
define root abstract entity ZD_IntercoProposalVDocFlow
{
  dummy      : abap.string;
  Categories : composition [*] of ZD_IntercoProposalVDocFlowC;

}
