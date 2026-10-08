###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "EpicDetailController", ->
    ctrl = scope = $q = $rootScope = null
    mocks = {}
    subscriptions = {}

    ROUTING_KEY_EPICS = "changes.project.1.epics"
    ROUTING_KEY_US = "changes.project.1.userstories"

    epicModel = (attrs) ->
        return _.extend({
            id: 40, ref: 3, subject: "Épica", status: 1, neighbors: {}, _attrs: {},
            start_date: null, expected_completion_date: null, completion_date: null,
            completion_percent_done: 0, completion_percent_progress: 0, description_html: ""
        }, attrs)

    relatedUserstories = (ids) ->
        return Immutable.fromJS(_.map(ids, (id) -> {id: id, subject: "História #{id}"}))

    project = ->
        return {
            id: 1, slug: "projeto", name: "Projeto", members: [], roles: [],
            epic_statuses: [], my_permissions: []
        }

    _mocks = ->
        subscriptions = {}
        mocks.events = {
            subscribe: sinon.spy (scope, routingKey, callback) -> subscriptions[routingKey] = callback
        }
        mocks.editingTracker = {isEditing: sinon.stub().returns(false)}
        mocks.rs = {
            epics: {getByRef: sinon.stub()}
        }
        mocks.rs2 = {
            userstories: {listInEpic: sinon.stub()}
        }
        mocks.translate = {instant: sinon.stub().returnsArg(0)}
        mocks.projectService = {project: {toJS: -> project()}}
        mocks.modelTransform = {setObject: sinon.stub()}
        mocks.attachmentsFullService = {loadAttachments: sinon.stub()}
        mocks.appMetaService = {setAll: sinon.stub()}
        mocks.navUrls = {resolve: sinon.stub().returns("/url")}
        mocks.analytics = {trackEvent: sinon.stub()}

    createController = ->
        inject ($controller, _$q_, _$rootScope_) ->
            $q = _$q_
            $rootScope = _$rootScope_
            scope = $rootScope.$new()

            mocks.rs.epics.getByRef.returns($q.resolve(epicModel()))
            mocks.rs2.userstories.listInEpic.returns($q.resolve(relatedUserstories([10, 11])))

            ctrl = $controller "EpicDetailController", {
                $scope: scope
                $rootScope: $rootScope
                $tgRepo: {}
                $tgConfirm: {}
                $tgResources: mocks.rs
                tgResources: mocks.rs2
                $routeParams: {pslug: "projeto", epicref: "3"}
                $q: $q
                $tgLocation: {}
                $log: {}
                tgAppMetaService: mocks.appMetaService
                $tgAnalytics: mocks.analytics
                $tgNavUrls: mocks.navUrls
                $translate: mocks.translate
                $tgQueueModelTransformation: mocks.modelTransform
                tgErrorHandlingService: {}
                tgProjectService: mocks.projectService
                tgAttachmentsFullService: mocks.attachmentsFullService
                $tgEvents: mocks.events
                tgEditingTracker: mocks.editingTracker
            }
            $rootScope.$digest()

    emit = (routingKey, message) ->
        subscriptions[routingKey](message)
        $rootScope.$digest()

    resetLoaders = ->
        mocks.rs.epics.getByRef.reset()
        mocks.rs2.userstories.listInEpic.reset()

    beforeEach ->
        module "taigaBase"
        module "taigaEpics"

        _mocks()
        createController()

    it "assina as chaves de épicas e de histórias do projeto com o scope da tela e sem selfNotification", ->
        expect(mocks.events.subscribe).to.have.been.calledTwice
        expect(subscriptions).to.have.all.keys(ROUTING_KEY_EPICS, ROUTING_KEY_US)
        for call in mocks.events.subscribe.getCalls()
            expect(call.args[0]).to.be.equal(scope)
            expect(call.args[3]).to.be.undefined

    it "evento da épica aberta reconsulta a épica e a lista de histórias, e o scope recebe o que o servidor devolve", ->
        resetLoaders()
        mocks.rs.epics.getByRef.returns($q.resolve(epicModel({subject: "Alterada pela T·IA", completion_percent_done: 50})))
        mocks.rs2.userstories.listInEpic.returns($q.resolve(relatedUserstories([10, 11, 12])))

        emit(ROUTING_KEY_EPICS, {type: "change", matches: "epics.epic", pk: 40})

        expect(mocks.rs.epics.getByRef).to.have.been.calledOnce
        expect(mocks.rs2.userstories.listInEpic).to.have.been.calledOnce
        expect(scope.epic.subject).to.be.equal("Alterada pela T·IA")
        expect(ctrl.completionPercentDone).to.be.equal("50%")
        expect(scope.userstories.size).to.be.equal(3)

    it "evento de outra épica não consulta nem altera o scope", ->
        resetLoaders()

        emit(ROUTING_KEY_EPICS, {type: "change", matches: "epics.epic", pk: 99})

        expect(mocks.rs.epics.getByRef).not.to.have.been.called
        expect(mocks.rs2.userstories.listInEpic).not.to.have.been.called
        expect(scope.epic.subject).to.be.equal("Épica")

    it "evento em lote com lista de pks contendo a épica consulta", ->
        resetLoaders()
        mocks.rs.epics.getByRef.returns($q.resolve(epicModel({subject: "Reordenada"})))
        mocks.rs2.userstories.listInEpic.returns($q.resolve(relatedUserstories([10, 11])))

        emit(ROUTING_KEY_EPICS, {type: "change", matches: "epics.epic", pk: [1, 40]})

        expect(mocks.rs.epics.getByRef).to.have.been.calledOnce
        expect(scope.epic.subject).to.be.equal("Reordenada")

    it "evento de história da épica recarrega só a lista de histórias", ->
        resetLoaders()
        mocks.rs2.userstories.listInEpic.returns($q.resolve(relatedUserstories([10])))

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 11})

        expect(mocks.rs2.userstories.listInEpic).to.have.been.calledOnce
        expect(mocks.rs.epics.getByRef).not.to.have.been.called
        expect(scope.userstories.size).to.be.equal(1)

    it "evento de história fora da épica não recarrega a lista", ->
        resetLoaders()

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 99})

        expect(mocks.rs2.userstories.listInEpic).not.to.have.been.called

    it "evento de exclusão da própria épica não consulta", ->
        resetLoaders()

        emit(ROUTING_KEY_EPICS, {type: "delete", matches: "epics.epic", pk: 40})

        expect(mocks.rs.epics.getByRef).not.to.have.been.called
        expect(mocks.rs2.userstories.listInEpic).not.to.have.been.called
        expect(scope.epic.subject).to.be.equal("Épica")

    it "evento durante edição não consulta nem altera o scope, e consulta ao terminar a edição", ->
        mocks.editingTracker.isEditing.returns(true)
        resetLoaders()
        mocks.rs.epics.getByRef.returns($q.resolve(epicModel({subject: "Alterada pela T·IA"})))
        mocks.rs2.userstories.listInEpic.returns($q.resolve(relatedUserstories([10, 11])))

        emit(ROUTING_KEY_EPICS, {type: "change", matches: "epics.epic", pk: 40})

        expect(mocks.rs.epics.getByRef).not.to.have.been.called
        expect(scope.epic.subject).to.be.equal("Épica")

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(mocks.rs.epics.getByRef).to.have.been.calledOnce
        expect(scope.epic.subject).to.be.equal("Alterada pela T·IA")

    it "object:updated recarrega enquanto a tela está aberta e deixa de recarregar depois que o scope é destruído", ->
        mocks.rs.epics.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.epics.getByRef).to.have.been.calledOnce

        scope.$destroy()
        mocks.rs.epics.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.epics.getByRef).not.to.have.been.called

    it "epic:userstory:created da épica aberta recarrega enquanto a tela está aberta e não depois do destroy", ->
        mocks.rs.epics.getByRef.reset()
        $rootScope.$broadcast("epic:userstory:created", ctrl.scope.epicId)
        $rootScope.$digest()
        expect(mocks.rs.epics.getByRef).to.have.been.calledOnce

        scope.$destroy()
        mocks.rs.epics.getByRef.reset()
        $rootScope.$broadcast("epic:userstory:created", ctrl.scope.epicId)
        $rootScope.$digest()
        expect(mocks.rs.epics.getByRef).not.to.have.been.called
