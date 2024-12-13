[% BLOCK render_field %]
      [% SET key = field.key %]
      [% SET prefix = "${rapid_request_type}_${key}" %]
      [% SET included_material = 0 %]
      [% FOREACH material IN field.materials %]
        [% IF material == rapid_request_type %]
          [% SET included_material = 1 %]
        [% END %]
      [% END %]
      [% IF included_material && !field.exclude %]
      <li id="[% prefix %]_field">
        <label id="[% prefix %]label" for="[% key %]">[% IF field.label_variants %][% field.label_variants.$rapid_request_type %][% ELSE %][% field.label %][% END %]</label>
        [% SET validation_group = $field.required && $field.required.$rapid_request_type ? $field.required && $field.required.$rapid_request_type.group : 0 %]
        <input type="text" name="[% key %]" class="form-control[% IF $field_errors.$key %] has-error[% END %]"
               id="[% rapid_request_type %]_[% key %]_input"
               value="[% other.$key | html %]"
               [% IF field.help %]aria-describedby="[% prefix %]helpBlock"[% END %]
               [% IF validation_group %]data-validation-group="[% validation_group %]"[% END %]
                />
        [% IF field.help %]
        <span id="[% prefix %]helpBlock" class="help-block">[% field.help | html %]</span>
        [% END %]
      </li>
      [% END %]
[% END %]
[% BLOCK render_errors %]
  [% IF errors %]
  <div class="help-block has-error">
  <ul>
    [% FOREACH error IN errors %]
      <li>[% error | html %]</li>
    [% END %]
  </ul>
  </div>
  [% END %]
[% END %]
[% BLOCK render_create_form %]
[% PROCESS render_form_variant variant='create' %]
[% END %]
[% BLOCK render_edit_form %]
[% PROCESS render_form_variant variant='edit' %]
[% END %]
[% BLOCK render_form_variant %]
<form method="POST" action="[% here %]" id="[% rapid_request_type %]_[% variant %]_form">
  <fieldset class="form-group">
    <legend>Enter metadata</legend>
    [% IF variant == "create" %]
    <input name="stage" id="stage" value="validate" type="hidden"/>
    <input name="method" id="method" value="create" type="hidden"/>
    [% ELSE %]
    <input name="stage" id="stage" value="form" type="hidden"/>
    <input name="method" id="method" value="edititem" type="hidden"/>
    [% END %]
    <input name="RapidRequestType" value="[% rapid_request_type %]" type="hidden" />
    <input name="backend" id="backend" value="RapidILL" type="hidden"/>
    [% IF Koha.Version.major >= 24 %][% INCLUDE 'csrf-token.inc' %][% END %]
    <ul class="fields">
      [% FOREACH field IN whole.field_map %]
        [% PROCESS render_field field=field rapid_request_type=rapid_request_type field_errors=field_errors %]
      [% END %]
    </ul>
    <div id="[% rapid_request_type %]_messages">
    [% PROCESS render_errors errors=errors %]
    </div>
  </fieldset>
 [% IF variant != 'edit' %]
  <fieldset class="form-group">
    <legend>Patron options</legend>
    <ul class="fields">
      [% IF staff %]
      <li>
        <label for="cardnumber">Card number, username or surname:</label>
        <input class="form-control" type="text" required="required" autocomplete="off" name="cardnumber" id="cardnumber" type="text"
           value="[% whole.value.other.cardnumber %]" />
      </li>
      [% END %]
      <li>
        <label for="branchcode">Destination library:</label>
        <select class="form-control" id="branchcode" name="branchcode">
          [% FOREACH branch IN branches %]
            [% IF ( whole.value.other.branchcode == branch.branchcode ) %]
              <option value="[% branch.branchcode %]" selected="selected">[% branch.branchname %]</option>
            [% ELSE %]
              <option value="[% branch.branchcode %]">[% branch.branchname %]</option>
            [% END %]
          [% END %]
        </select>
      </li>
    </ul>
  </fieldset>
  [% END %]
  <fieldset class="form-group">
    [% IF variant=="create" %]
    <button type="submit" class="btn btn-primary">Make request</button>
    <a class="btn btn-default" href="[% requests_back_url %]"><span class="fa fa-arrow-left"></span> Back to ill requests</a>
    [% ELSE %]
    <button type="submit" class="btn btn-primary">Update</button>
    <a class="btn btn-default" href="[% requests_back_url %]"><span class="fa fa-arrow-left"></span> Back to ill request</a>
    [% END %]
  </fieldset>
</form>
[% END %]