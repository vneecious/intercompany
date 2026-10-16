//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 05.08.2026
// Description    : Cierre de la integracion CA-CONTAB (Simulate/Post/Storno + evento Posted)
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
// F4 / DD-F4-1 / DD-F4-3 - Parametro tipado del evento RAP "Posted",
// declarado sobre CalcLine (ZI_ReingCALine) en ZI_ReingCARun.bdef.
// Payload segun ET §8b (SUP-07): el handler de CONTAB solo necesita
// filtrar por OpType y llamar a
// zcl_reing_ca_an2_regenerator=>regenerate( iv_origin_run_id, iv_origin_line_num ).
// Los eventos RAP exigen una CDS abstract entity como parametro (no una
// estructura DDIC) -- mismo tipo de artefacto que ZI_ReingCAExportResult (F6-07).
// Los data elements son los reales de ZREING_CA_LINE_A, no genericos.
//----------------------------------------------------------------------
@EndUserText.label: 'CA - Payload evento Posted'

define abstract entity ZI_ReingCAPostedEvent
{
  LineNum : zreing_line_num;
  OpType  : zreing_op_type;
}
