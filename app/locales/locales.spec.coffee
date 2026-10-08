###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "locales pt-br, en e es", ->
    load = (lang) ->
        fetch("/base/app/locales/taiga/locale-#{lang}.json").then (response) -> response.json()

    flatten = (obj, prefix = "") ->
        keys = []
        for own key, value of obj
            if _.isPlainObject(value)
                keys = keys.concat(flatten(value, "#{prefix}#{key}."))
            else
                keys.push("#{prefix}#{key}")
        return keys

    keysOf = (locale, block) ->
        flatten(locale[block] or {}).sort()

    for block in ["HOME_LANDING", "NEWS_ADMIN", "STORY_POINTS_GUIDE"]
        do (block) ->
            it "#{block} tem o mesmo conjunto de chaves nos três idiomas", ->
                Promise.all([load("pt-br"), load("en"), load("es")]).then ([ptbr, en, es]) ->
                    expect(keysOf(ptbr, block).length).to.be.above(0)
                    expect(keysOf(en, block)).to.be.deep.equal(keysOf(ptbr, block))
                    expect(keysOf(es, block)).to.be.deep.equal(keysOf(ptbr, block))

    it "guia de story points tem título da página e subtítulo da introdução em pt-br", ->
        load("pt-br").then (ptbr) ->
            expect(ptbr.STORY_POINTS_GUIDE.PAGE_TITLE).to.be.a("string").and.not.empty
            expect(ptbr.STORY_POINTS_GUIDE.INTRO_SUBTITLE).to.be.a("string").and.not.empty

    describe "chaves usadas nos templates do cartão 20 existem no pt-br", ->
        templates = [
            "news-admin/news-admin.html"
            "home/home-landing.html"
            "components/news-carousel/news-carousel.html"
            "components/institutional-footer/institutional-footer.html"
        ]

        resolve = (locale, path) ->
            value = locale
            for part in path.split(".")
                return undefined if not value?
                value = value[part]
            return value

        for name in templates
            do (name) ->
                it "#{name}", ->
                    html = null
                    module "templates"
                    inject ($templateCache) -> html = $templateCache.get(name)
                    expect(html, "template #{name} no $templateCache").to.be.a("string")

                    used = _.uniq(html.match(/(?:NEWS_ADMIN|HOME_LANDING)\.[A-Z0-9_.]+[A-Z0-9]/g) or [])
                    expect(used.length, "nenhuma chave encontrada em #{name}").to.be.above(0)

                    load("pt-br").then (ptbr) ->
                        missing = _.filter used, (key) -> not _.isString(resolve(ptbr, key))
                        expect(missing, "chaves sem tradução em pt-br").to.be.deep.equal([])

    describe "chaves usadas no código do cartão 20 existem no pt-br", ->
        # Chaves montadas dinamicamente no news-admin.controller.coffee
        controllerKeys = [
            "NEWS_ADMIN.DELETE_TITLE"
            "NEWS_ADMIN.ERRORS.GENERIC", "NEWS_ADMIN.ERRORS.FORBIDDEN", "NEWS_ADMIN.ERRORS.IMAGE_REQUIRED"
            "NEWS_ADMIN.ERRORS.INVALID_IMAGE", "NEWS_ADMIN.ERRORS.IMAGE_TOO_LARGE", "NEWS_ADMIN.ERRORS.TITLE_REQUIRED"
            "NEWS_ADMIN.ERRORS.TITLE_TOO_LONG", "NEWS_ADMIN.ERRORS.DESCRIPTION_TOO_LONG", "NEWS_ADMIN.ERRORS.ORDER_NEGATIVE"
            "NEWS_ADMIN.ERRORS.ORDER_INVALID", "NEWS_ADMIN.ERRORS.SLIDE_NOT_FOUND", "NEWS_ADMIN.ERRORS.EMPTY_BULK"
        ]

        resolveKey = (locale, path) ->
            value = locale
            for part in path.split(".")
                return undefined if not value?
                value = value[part]
            return value

        it "chaves montadas no controller da gestão do carrossel", ->
            load("pt-br").then (ptbr) ->
                missing = _.filter controllerKeys, (key) -> not _.isString(resolveKey(ptbr, key))
                expect(missing, "chaves sem tradução em pt-br").to.be.deep.equal([])

        it "literais NEWS_ADMIN.* e HOME_LANDING.* do app.js (prefixo de bloco vale para chave dinâmica)", ->
            script = _.find(document.scripts, (node) -> /\/js\/app\.js(\?|$)/.test(node.src))
            expect(script, "app.js carregado pelo karma").to.be.ok
            Promise.all([fetch(script.src).then((r) -> r.text()), load("pt-br")]).then ([source, ptbr]) ->
                used = _.uniq(source.match(/(?:NEWS_ADMIN|HOME_LANDING)\.[A-Z0-9_.]+[A-Z0-9]/g) or [])
                expect(used.length).to.be.above(0)
                missing = _.filter used, (key) ->
                    value = resolveKey(ptbr, key)
                    not (_.isString(value) or _.isPlainObject(value))
                expect(missing, "chaves sem tradução em pt-br").to.be.deep.equal([])
