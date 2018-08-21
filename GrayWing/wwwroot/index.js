/// <reference path="lib/jquery-3.3.1.min.js"/>

function SparqlClient(endpointUrl) {
    this._endpointUrl = endpointUrl;
}

SparqlClient.prototype.query = function (queryExpr) {
    var d = $.Deferred();
    $.post({
        url: this._endpointUrl,
        data: queryExpr,
        contentType: "text/plain; charset=UTF-8"
    }).done(function (response, status, xhr) {
        d.resolve(response, xhr.status);
    }).fail(function (xhr, status, error) {
        var response = xhr.responseText;
        d.reject(response, xhr.status);
    });
    return d;
}