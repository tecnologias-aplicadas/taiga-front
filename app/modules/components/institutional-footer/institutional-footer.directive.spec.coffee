###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgInstitutionalFooter", () ->
    scope = compile = null

    beforeEach ->
        module "templates"
        module "taigaComponents"

        module ($provide) ->
            $provide.value "translateFilter", (value) -> value
            return null

        inject ($rootScope, $compile) ->
            scope = $rootScope.$new()
            compile = $compile

    render = (template) ->
        elm = compile(template)(scope)
        scope.$apply()
        return elm

    it "na home mostra os logos e a linha de texto, sem símbolo de direitos autorais", () ->
        elm = render("<tg-institutional-footer></tg-institutional-footer>")
        footer = elm.find("footer.hl-footer")
        expect(footer.length).to.be.equal(1)
        expect(footer.hasClass("hl-footer--compact")).to.be.false
        expect(elm.find("img.hl-footer__img").length).to.be.equal(4)
        copy = elm.find(".hl-footer__copy")
        expect(copy.length).to.be.equal(1)
        expect(copy.text().trim()).to.be.equal("HOME_LANDING.FOOTER_COPY")
        expect(elm.html()).not.to.contain("©")

    it "no login fica compacto, com os logos e sem a linha de texto", () ->
        elm = render("<tg-institutional-footer compact=\"true\"></tg-institutional-footer>")
        footer = elm.find("footer.hl-footer")
        expect(footer.length).to.be.equal(1)
        expect(footer.hasClass("hl-footer--compact")).to.be.true
        expect(elm.find("img.hl-footer__img").length).to.be.equal(4)
        expect(elm.find(".hl-footer__copy").length).to.be.equal(0)
        expect(elm.html()).not.to.contain("©")
