###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "IssueDetailController", ->
    ctrl = scope = $q = $rootScope = null
    mocks = {}
    subscriptions = {}

    ROUTING_KEY = "changes.project.1.issues"

    issueModel = (attrs) ->
        return _.extend({
            id: 30, ref: 9, subject: "Issue", status: 1, type: 1, severity: 1, priority: 1,
            milestone: null, neighbors: {}, description_html: "", _attrs: {}
        }, attrs)

    project = ->
        return {
            id: 1, slug: "projeto", name: "Projeto", members: [], roles: [],
            issue_statuses: [], issue_types: [], severities: [], priorities: [],
            my_permissions: [], is_issues_activated: true
        }

    _mocks = ->
        subscriptions = {}
        mocks.events = {
            subscribe: sinon.spy (scope, routingKey, callback) -> subscriptions[routingKey] = callback
        }
        mocks.editingTracker = {isEditing: sinon.stub().returns(false)}
        mocks.rs = {
            issues: {getByRef: sinon.stub()}
            sprints: {get: sinon.stub()}
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

            mocks.rs.issues.getByRef.returns($q.resolve(issueModel()))

            ctrl = $controller "IssueDetailController", {
                $scope: scope
                $rootScope: $rootScope
                $tgRepo: {}
                $tgConfirm: {}
                $tgResources: mocks.rs
                $routeParams: {pslug: "projeto", issueref: "9"}
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

    emit = (message) ->
        subscriptions[ROUTING_KEY](message)
        $rootScope.$digest()

    expectIssueReloaded = (subject) ->
        mocks.rs.issues.getByRef.reset()
        mocks.rs.issues.getByRef.returns($q.resolve(issueModel({subject: subject, status: 2})))

    beforeEach ->
        module "taigaBase"
        module "taigaIssues"

        _mocks()
        createController()

    it "assina a chave de issues do projeto com o scope da tela e sem selfNotification", ->
        expect(mocks.events.subscribe).to.have.been.calledOnce
        expect(subscriptions).to.have.all.keys(ROUTING_KEY)
        expect(mocks.events.subscribe.firstCall.args[0]).to.be.equal(scope)
        expect(mocks.events.subscribe.firstCall.args[3]).to.be.undefined

    it "evento da issue aberta reconsulta o servidor e o scope passa a ter o objeto devolvido", ->
        expectIssueReloaded("Alterada pela T·IA")

        emit({type: "change", matches: "issues.issue", pk: 30})

        expect(mocks.rs.issues.getByRef).to.have.been.calledOnce
        expect(scope.issue.subject).to.be.equal("Alterada pela T·IA")
        expect(scope.issue.status).to.be.equal(2)

    it "evento de outra issue não consulta nem altera o scope", ->
        expectIssueReloaded("Outra")

        emit({type: "change", matches: "issues.issue", pk: 99})

        expect(mocks.rs.issues.getByRef).not.to.have.been.called
        expect(scope.issue.subject).to.be.equal("Issue")

    it "evento em lote com lista de pks contendo a issue consulta", ->
        expectIssueReloaded("Movida em lote")

        emit({type: "change", matches: "issues.issue", pk: [2, 30]})

        expect(mocks.rs.issues.getByRef).to.have.been.calledOnce
        expect(scope.issue.subject).to.be.equal("Movida em lote")

    it "evento durante edição não consulta nem altera o scope, e consulta ao terminar a edição", ->
        mocks.editingTracker.isEditing.returns(true)
        expectIssueReloaded("Alterada pela T·IA")

        emit({type: "change", matches: "issues.issue", pk: 30})

        expect(mocks.rs.issues.getByRef).not.to.have.been.called
        expect(scope.issue.subject).to.be.equal("Issue")

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(mocks.rs.issues.getByRef).to.have.been.calledOnce
        expect(scope.issue.subject).to.be.equal("Alterada pela T·IA")

    it "evento de exclusão da própria issue não consulta", ->
        expectIssueReloaded("Apagada")

        emit({type: "delete", matches: "issues.issue", pk: 30})

        expect(mocks.rs.issues.getByRef).not.to.have.been.called
        expect(scope.issue.subject).to.be.equal("Issue")

    it "object:updated recarrega enquanto a tela está aberta e deixa de recarregar depois que o scope é destruído", ->
        mocks.rs.issues.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.issues.getByRef).to.have.been.calledOnce

        scope.$destroy()
        mocks.rs.issues.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.issues.getByRef).not.to.have.been.called
