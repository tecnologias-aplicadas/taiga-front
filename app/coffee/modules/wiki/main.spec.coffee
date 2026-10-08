###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "WikiDetailController", ->
    ctrl = scope = $q = $rootScope = null
    mocks = {}
    subscriptions = {}

    ROUTING_KEY = "changes.project.1.wiki"

    wikiModel = (attrs) ->
        return _.extend({
            id: 50, slug: "home", content: "# Home", html: "<h1>Home</h1>",
            editions: 1, version: 1, modified_date: "2026-09-28T10:00:00Z"
        }, attrs)

    project = ->
        return {
            id: 1, slug: "projeto", name: "Projeto", members: [], roles: [],
            my_permissions: [], is_wiki_activated: true
        }

    _mocks = ->
        subscriptions = {}
        mocks.events = {
            subscribe: sinon.spy (scope, routingKey, callback) -> subscriptions[routingKey] = callback
        }
        mocks.editingTracker = {isEditing: sinon.stub().returns(false)}
        mocks.activityService = {fetchEntries: sinon.stub()}
        mocks.rs = {
            wiki: {getBySlug: sinon.stub(), listLinks: sinon.stub()}
        }
        mocks.translate = {instant: sinon.stub().returnsArg(0)}
        mocks.projectService = {project: {toJS: -> project()}}
        mocks.attachmentsFullService = {loadAttachments: sinon.stub()}
        mocks.appMetaService = {setAll: sinon.stub()}
        mocks.navUrls = {resolve: sinon.stub().returns("/url")}
        mocks.errorHandlingService = {permissionDenied: sinon.stub()}

    createController = ->
        inject ($controller, _$q_, _$rootScope_) ->
            $q = _$q_
            $rootScope = _$rootScope_
            scope = $rootScope.$new()

            mocks.rs.wiki.getBySlug.returns($q.resolve(wikiModel()))
            mocks.rs.wiki.listLinks.returns($q.resolve([]))

            ctrl = $controller "WikiDetailController", {
                $scope: scope
                $rootScope: $rootScope
                $tgRepo: {}
                $tgModel: {}
                $tgConfirm: {}
                $tgResources: mocks.rs
                $routeParams: {pslug: "projeto", slug: "home"}
                $q: $q
                $tgLocation: {}
                $filter: {}
                $log: {}
                tgAppMetaService: mocks.appMetaService
                $tgNavUrls: mocks.navUrls
                $tgAnalytics: {}
                $translate: mocks.translate
                tgErrorHandlingService: mocks.errorHandlingService
                tgProjectService: mocks.projectService
                tgAttachmentsFullService: mocks.attachmentsFullService
                $tgEvents: mocks.events
                tgEditingTracker: mocks.editingTracker
                tgActivityService: mocks.activityService
            }
            $rootScope.$digest()

    emit = (message) ->
        subscriptions[ROUTING_KEY](message)
        $rootScope.$digest()

    expectWikiReloaded = (content) ->
        mocks.rs.wiki.getBySlug.reset()
        mocks.rs.wiki.getBySlug.returns($q.resolve(wikiModel({content: content, editions: 2})))
        mocks.activityService.fetchEntries.reset()

    beforeEach ->
        module "taigaBase"
        module "taigaWiki"

        _mocks()
        createController()

    it "assina a chave de wiki do projeto com o scope da tela e sem selfNotification", ->
        expect(mocks.events.subscribe).to.have.been.calledOnce
        expect(subscriptions).to.have.all.keys(ROUTING_KEY)
        expect(mocks.events.subscribe.firstCall.args[0]).to.be.equal(scope)
        expect(mocks.events.subscribe.firstCall.args[3]).to.be.undefined

    it "evento da página aberta reconsulta o servidor, o scope recebe a página devolvida e o histórico recarrega", ->
        expectWikiReloaded("# Home editada pela T·IA")

        emit({type: "change", matches: "wiki.wiki_page", pk: 50})

        expect(mocks.rs.wiki.getBySlug).to.have.been.calledOnce
        expect(scope.wiki.content).to.be.equal("# Home editada pela T·IA")
        expect(scope.wiki.editions).to.be.equal(2)
        expect(mocks.activityService.fetchEntries).to.have.been.calledWith(true)

    it "evento de outra página não consulta nem altera o scope", ->
        expectWikiReloaded("Outra")

        emit({type: "change", matches: "wiki.wiki_page", pk: 99})

        expect(mocks.rs.wiki.getBySlug).not.to.have.been.called
        expect(mocks.activityService.fetchEntries).not.to.have.been.called
        expect(scope.wiki.content).to.be.equal("# Home")

    it "evento em lote com lista de pks contendo a página consulta", ->
        expectWikiReloaded("Em lote")

        emit({type: "change", matches: "wiki.wiki_page", pk: [4, 50]})

        expect(mocks.rs.wiki.getBySlug).to.have.been.calledOnce
        expect(scope.wiki.content).to.be.equal("Em lote")

    it "evento de exclusão da própria página não consulta", ->
        expectWikiReloaded("Apagada")

        emit({type: "delete", matches: "wiki.wiki_page", pk: 50})

        expect(mocks.rs.wiki.getBySlug).not.to.have.been.called
        expect(scope.wiki.content).to.be.equal("# Home")

    it "evento durante edição não consulta nem altera o scope, e consulta ao terminar a edição", ->
        mocks.editingTracker.isEditing.returns(true)
        expectWikiReloaded("# Home editada pela T·IA")

        emit({type: "change", matches: "wiki.wiki_page", pk: 50})

        expect(mocks.rs.wiki.getBySlug).not.to.have.been.called
        expect(scope.wiki.content).to.be.equal("# Home")

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(mocks.rs.wiki.getBySlug).to.have.been.calledOnce
        expect(scope.wiki.content).to.be.equal("# Home editada pela T·IA")
