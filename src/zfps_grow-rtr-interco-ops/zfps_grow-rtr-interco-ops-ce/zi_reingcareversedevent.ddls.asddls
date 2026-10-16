//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 05.08.2026
// Description    : Cierre de la integracion CA-CONTAB (Simulate/Post/Storno + evento Posted)
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
// F4 / DD-F4-1 / DD-F4-3 - Parametro tipado del evento RAP "Reversed",
// declarado sobre CalcLine (ZI_ReingCALine) en ZI_ReingCARun.bdef.
// Sin OpType (ET §8b / SUP-07: el evento de anulacion no lo transporta).
//----------------------------------------------------------------------
@EndUserText.label: 'CA - Payload evento Reversed'

define abstract entity ZI_ReingCAReversedEvent
{
  LineNum : zreing_line_num;
}
