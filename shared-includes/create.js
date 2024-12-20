// Build the groups used for validation
function buildValidationGroups(type) {
    const groups = new Map();
    for (const field of Object.keys(fieldmap)) {
        const f = fieldmap[field];
        if (f.required && f.required[type] && f.required[type].group) {
            const group = f.required[type].group;
            const g0 = groups.get(group);
            if (!g0) {
                groups.set(group, [field]);
            } else {
                g0.push(field);
            }
        }
    }
    return groups;
};

// Does a given group of fields have at least one populated input?
function isGroupValid(fields, inputs) {
    return fields.findIndex(function (field) {
        const input = inputs.get(field);
        if (input && input.value.length > 0) {
            return true;
        }
        return false;
    }) >= 0;

};

// Validate fields and display warnings
function validateFields(form, type) {
    const inputs = new Map();
    const filledgroups = new Map();
    for (const input of form.getElementsByTagName('input')) {
        const name = input.getAttribute('name');
        inputs.set(name, input);
        const groupattr = input.attributes.getNamedItem('data-validation-group');
        if (groupattr !== null) {
            const groupname = groupattr.value;
            if (input.value.match(/[^ ]/)) {
                filledgroups.set(groupname, name);
            }
        }
    }
    for (const input of inputs.values()) {
        const groupattr = input.attributes.getNamedItem('data-validation-group');
        if (groupattr !== null) {
            const groupname = groupattr.value;
            if (filledgroups.has(groupname)) {
                input.classList.remove("is-invalid");
                input.classList.remove("has-errors");
                input.classList.add("is-valid");
                input.setCustomValidity("");
            } else {
                input.classList.add("is-invalid");
                input.classList.add("has-errors");
                input.classList.remove("is-valid");
                input.setCustomValidity("x");
            }
        }
    }
    // Get our validation groups
    const messages = [];
    const errorFields = new Set();
    const groups = buildValidationGroups(type);
    for (const fields of groups.values()) {
        if (!isGroupValid(fields, inputs)) {
            const fieldNames = fields.map(function (field) {
                errorFields.add(field);
                return typeof fieldmap[field].label === 'object' ?
                    fieldmap[field].label[type] :
                    fieldmap[field].label;
            });
            messages.push(
                "[% MSG.you_must_complete_fields %] " + fieldNames.join(', ')
            );
        }
    }

    for (const name of inputs.keys()) {
        if (errorFields.has(name)) {
            inputs.get(name).parentElement.classList.add("has-error");
            inputs.get(name).classList.add("is-invalid");
        } else {
            inputs.get(name).parentElement.classList.remove("has-error");
            inputs.get(name).classList.remove("is-invalid");
        }
    }
    return messages;
};

let hasValidated = new Set();

const doSubmit = (event, form, formId, type) => {
    const messages = validateFields(form, type);
    const container = document.getElementById(type + '_messages');
    for (const c of container.children) {
        c.remove();
    }
    if (messages.length > 0) {
        if (!hasValidated.has(type)) {
            hasValidated.add(type);
            form.classList.add("was-validated");
            form.addEventListener('change', () => validateFields(form, type));
        }
        event.preventDefault();
        event.stopPropagation();
    }
};

const initForm = (form, formId, type) => {
    const id = '#' + formId + ' #cardnumber';
    if (typeof patron_autocomplete === "function") {
        patron_autocomplete(
            $(id),
            {
                'on-select-callback': function( event, ui ) {
                    $(id).val( ui.item.cardnumber );
                    return false;
                }
            }


        );
    }
    form.addEventListener('submit', (event) => doSubmit(event, form, formId, type));
};

for (const type of ['Book', 'Article', 'BookChapter']) {
    for (const o of ['create', 'edit']) {
        const formId = type + '_' + o + '_form';
        const form = document.getElementById(formId);
        if (form) {
            initForm(form, formId, type);
        }
    }
}
