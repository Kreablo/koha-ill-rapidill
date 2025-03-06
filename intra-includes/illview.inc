[% cwd = whole.cwd %]
[% TRY %]
    [% lang_file = "${cwd}/l10n/${whole.lang_dialect}"_".inc" %]
    [% PROCESS "$lang_file" %]
[% CATCH %]
    [% TRY %]
        [% lang_file = "${cwd}/l10n/${whole.lang_all}"_".inc" %]
        [% PROCESS "$lang_file" %]
    [% CATCH %]
        [% PROCESS "${cwd}/l10n/default.inc" %]
    [% END %]
[% END %]
[% SET illrequest_id = request.illrequest_id %]
<style>
  #rapidill-history {
     display: block;
  }
</style>
  [% IF whole.request_info && whole.request_info.HistoryTransactions %]
    [% SET transaction_history = whole.request_info.HistoryTransactions.TranHistory %]
    [% IF transaction_history && transaction_history.size > 0 %]
      <div id="rapidill-history">
      <h4>[% MSG.request_history_heading %]</h4>
      [% FOREACH trans IN transaction_history %]
         <p><span class="date">[% trans.TransactionDate %]</span> : <strong>[% MSG.request_history_line | html %]</strong> "[% trans.StateType | html %]"</p>
      [% END %]
      </div>
    [% END %]
  [% END %]
<script>
  addEventListener("DOMContentLoaded", (event) => {
    try {
      const h = document.getElementById('rapidill-history');
      const rlog = document.getElementById('requestLog');
      const b = rlog.getElementsByClassName('modal-body');
      if (b.length > 0 && h) {
        h.remove();
        b[0].append(h);
      }
      const ds = rlog.getElementsByClassName('date');
      for (let i = 0; i < ds.length; i++) {
         try {
            const dt = new Date(ds[i].textContent);
            ds[i].textContent = dt.toLocaleDateString() + ' ' + dt.toLocaleTimeString();
         } catch (de) {
         }
      }
    } catch (e) {
    }
  });
</script>
