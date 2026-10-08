###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "idioma do último usuário nas telas sem login", ->

    describe "taiga.resolveLanguage (bootstrap e serviço)", ->
        it "usuário autenticado usa o próprio idioma, ou o padrão da instância", ->
            expect(taiga.resolveLanguage({lang: "es"}, "pt-br", "en")).to.be.equal("es")
            expect(taiga.resolveLanguage({lang: null}, "es", "pt-br")).to.be.equal("pt-br")
            expect(taiga.resolveLanguage({}, "es", null)).to.be.equal("en")

        it "sem usuário, usa o idioma do último que entrou neste navegador, senão o padrão", ->
            expect(taiga.resolveLanguage(null, "es", "pt-br")).to.be.equal("es")
            expect(taiga.resolveLanguage(null, null, "pt-br")).to.be.equal("pt-br")
            expect(taiga.resolveLanguage(null, null, null)).to.be.equal("en")

        it "lê a chave gravada pelo $tgStorage, e devolve null para quem nunca entrou", ->
            localStorage.removeItem("lastUserLang")
            expect(taiga.lastUserLangFromStorage()).to.be.null
            localStorage.setItem("lastUserLang", JSON.stringify("es"))
            expect(taiga.lastUserLangFromStorage()).to.be.equal("es")
            localStorage.setItem("lastUserLang", "{nao e json")
            expect(taiga.lastUserLangFromStorage()).to.be.null
            localStorage.removeItem("lastUserLang")

    describe "$tgAuth", ->
        auth = null
        mocks = {}
        stored = {}

        _mocks = ->
            module ($provide) ->
                stored = {}
                mocks.storage = {
                    get: sinon.spy((key) -> if stored[key]? then stored[key] else null)
                    set: sinon.spy((key, value) -> stored[key] = value)
                    remove: sinon.spy((key) -> delete stored[key])
                    clear: sinon.stub()
                }
                mocks.translate = {use: sinon.stub(), preferredLanguage: sinon.stub()}
                mocks.config = {get: sinon.stub()}
                mocks.config.get.withArgs("defaultLanguage").returns("pt-br")
                mocks.config.get.withArgs("themes").returns(["taiga"])
                mocks.currentUserService = {setUser: sinon.stub(), removeUser: sinon.stub()}
                mocks.themeService = {use: sinon.stub()}
                mocks.analytics = {setUserId: sinon.stub()}

                $provide.value "$tgStorage", mocks.storage
                $provide.value "$tgModel", {make_model: sinon.stub()}
                $provide.value "$tgRepo", {}
                $provide.value "$tgHttp", {}
                $provide.value "$tgUrls", {resolve: sinon.stub(), update: sinon.stub()}
                $provide.value "$tgConfig", mocks.config
                $provide.value "$tgUserPilot", {}
                $provide.value "$translate", mocks.translate
                $provide.value "tgCurrentUserService", mocks.currentUserService
                $provide.value "tgThemeService", mocks.themeService
                $provide.value "$tgAnalytics", mocks.analytics
                return null

        user = (lang) ->
            attrs = {id: 1, username: "u", lang: lang}
            return _.extend({getAttrs: -> attrs}, attrs)

        beforeEach ->
            window._taigaAvailableThemes = ["taiga"]
            module "taigaAuth"
            _mocks()
            inject ($tgAuth) -> auth = $tgAuth

        it "ao entrar, grava o idioma do usuário em lastUserLang e o aplica", ->
            auth.setUser(user("es"))
            expect(stored.lastUserLang).to.be.equal("es")
            expect(mocks.translate.preferredLanguage).to.be.calledWith("es")
            expect(mocks.translate.use).to.be.calledWith("es")

        it "ao sair, mantém lastUserLang e aplica esse idioma na hora", ->
            auth.setUser(user("es"))
            mocks.translate.use.reset()
            mocks.translate.preferredLanguage.reset()

            auth.logout()

            expect(stored.lastUserLang).to.be.equal("es")
            expect(mocks.storage.remove).not.to.be.calledWith("lastUserLang")
            expect(mocks.storage.clear.callCount).to.be.equal(0)
            expect(mocks.translate.preferredLanguage).to.be.calledWith("es")
            expect(mocks.translate.use).to.be.calledWith("es")

        it "outro usuário com idioma diferente substitui a chave", ->
            auth.setUser(user("es"))
            auth.logout()
            auth.setUser(user("en"))
            expect(stored.lastUserLang).to.be.equal("en")
            expect(mocks.translate.use.lastCall.args[0]).to.be.equal("en")

        it "usuário sem idioma não grava a chave e fica no padrão da instância", ->
            auth.setUser(user(null))
            expect(stored.lastUserLang).to.be.undefined
            expect(mocks.translate.use.lastCall.args[0]).to.be.equal("pt-br")

        it "quem nunca entrou neste navegador segue no padrão da instância", ->
            auth.logout()
            expect(stored.lastUserLang).to.be.undefined
            expect(mocks.translate.use.lastCall.args[0]).to.be.equal("pt-br")
