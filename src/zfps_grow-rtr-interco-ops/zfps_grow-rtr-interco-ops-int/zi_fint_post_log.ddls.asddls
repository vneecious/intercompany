@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interfaz - Log Posting Interes Mora'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_FINT_POST_LOG
  as select from zfint_post_log
{
  key log_id            as LogId,
      run_id            as RunId,
      doc_status        as DocStatus,
      run_status        as RunStatus,
      severity          as Severity,
      msgid             as MsgId,
      msgno             as MsgNo,
      msg_text          as MsgText,
      bukrs             as CompanyCode,
      vbund             as TradingPartner,
      doc_no            as DocumentNumber,
      intrun_id         as InterestRunId,
      concepto          as Concepto,
      source_belnr      as SourceAccountingDocument,
      source_gjahr      as SourceFiscalYear,
      cons_belnr        as ConsAccountingDocument,
      cons_gjahr        as ConsFiscalYear,
      doc_class         as DocClass,
      int_curr          as InterestCurrency,
      int_amount        as InterestAmount,
      dias_mora         as DaysInArrears,
      cons_generation   as ConsGeneration,
      parent_cons_belnr as ParentConsAccountingDocument,
      cancel_belnr      as CancelAccountingDocument,
      erdat             as CreationDate,
      erzet             as CreationTime,
      ernam             as CreatedByUser
}
