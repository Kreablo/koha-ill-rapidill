
(function() {

    const rapidILLArticleFields = new Map([
        ['author', 'ArticleAuthor'],
        ['issue', 'JournalIssue'],
        ['title', 'ArticleTitle'],
        ['page', 'ArticlePages'],
        ['volume', 'JournalVol'],
        ['journaltitle', 'PatronJournalTitle'],
        ['ISSNS', 'SuggestedIssns'],
        ['month', 'JournalMonth'],
        ['year', 'PatronJournalYear'],
        ['ISBNS', 'SuggestedIsbns']
    ]);

    const rapidILLBookChapterFields = rapidILLArticleFields;

    const rapidIllSetField = (message, type, fieldname) => {
        const fields = type === 'Article' ? rapidILLArticleFields : rapidILLBookChapterFields;
        const rfn = fields.get(fieldname);
        if (rfn && message[fieldname]) {
            const input = document.getElementById(type + '_' + rfn + '_input');
            if (input) {
                input.value = message[fieldname];
                input.dispatchEvent(new Event('keyup'));
            }
        }
    };

    const prepareMessage = (data) => {
        const m = data.message;
        if (m) {
            return {
                issue: m.issue,
                page: m.page,
                title: m.title ? m.title.join('. ') : '',
                volume: m.volume,
                author: m.author ? m.author.map((a) => a.given + ' ' + a.family).join('; ') : '',
                journaltitle: m['container-title'] ? m['container-title'].join('. ') : '',
                ISSN: m.ISSN && Array.isArray(m.ISSN) && m.ISSN.length > 0 ? m.ISSN[0] : '',
                ISSNS: m.ISSN && Array.isArray(m.ISSN) ? m.ISSN.join(' ') : '',
                ISBNS: m.ISBN && Array.isArray(m.ISBN) ? m.ISBN.join(' ') : '',
                year: m.published && m.published['date-parts'] && m.published['date-parts'].length > 0 && m.published['date-parts'][0].length > 0 ? m.published['date-parts'][0][0] : '',
                month: m.published && m.published['date-parts'] && m.published['date-parts'].length > 0 && m.published['date-parts'][0].length > 1 ? m.published['date-parts'][0][1] : ''
            };
        }

        const r = data.result;
        if (r) {
            return {
                issue: r.issue,
                page: r.page,
                title: r.title,
                author: r.authors ? r.authors.map((a) => a.name).join('; ') : '',
                journaltitle: r.fulljournalname,
                ISSN: r.issn,
                ISSNS: r.issn,
                ISBNS: r.isbn,
                year: r.sortpubdate ? r.sortpubdate.slice(0,4) : '',
                month: ''
            };
        }
        return undefined;
    };

    const backends = {
        RapidILL: {
            selectName: 'RapidRequestType',
            setField: rapidIllSetField
        },
    };

    const success = (backend, type, form) => (data) => {
        const message = prepareMessage(data);
        const b = backends[backend];
        if (b) {
            for (const p of Object.getOwnPropertyNames(message)) {
                if (message[p]) {
                    b.setField(message, type, p);
                }
            }
        }
        form.dispatchEvent(new Event('change'));
    };

    const crossref = function(doi, type, backend, form) {
        if (doi.length === 0) return;
        var url = '/__p__/crossref/' + doi;
        $.ajax({
            dataType: "json",
            url: url,
            success: success(backend, type, form)
        });
    };

    var timeout;
    function debounce(func, wait, immediate) {
        return function () {
            var context = this,
                args = arguments;
            var later = function () {
                timeout = null;
                if (!immediate) func.apply(context, args);
            };
            var callNow = immediate && !timeout;
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
            if (callNow) func.apply(context, args);
        };
    }

    const initiateType = (type) => {
        const doiInput = document.getElementById(type + "_DOI_input");
        if (doiInput) {
            let form = doiInput.parentElement;
            while (form && form.tagName.toLowerCase() !== "form") {
                form = form.parentElement;
            }
            if (form) {
                let backend = undefined;
                for (const input of form.getElementsByTagName("input")) {
                    if (input.name == "backend") {
                        backend = input.value;
                        break;
                    }
                }
                if (backend) {
                    doiInput.addEventListener('input', (event) => {
                        event.preventDefault();
                        event.stopPropagation();
                        debounce(crossref, 1000)(doiInput.value, type, backend, form);
                    });
                }
                if (doiInput.value !== "") {
                    crossref(doiInput.value, type, backend, form);
                }
            }
        }
    };

    const initiate = () => {
        ['Article', 'BookChapter'].map((type) => initiateType(type));
    };

    initiate();
})();

