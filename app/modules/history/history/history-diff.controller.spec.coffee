###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "ActivitiesDiffController", ->
    provide = null
    controller = null
    sce = null
    mocks = {}

    _mockTranslate = () ->
        mocks.translate = {
            instant: sinon.stub().returnsArg(0)
        }
        provide.value "$translate", mocks.translate

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTranslate()
            return null

    beforeEach ->
        module "taigaHistory"
        _mocks()

        inject ($controller, $sce) ->
            controller = $controller
            sce = $sce

    it "Check diff between tags", () ->
        activitiesDiffCtrl = controller "ActivitiesDiffCtrl"

        activitiesDiffCtrl.type = "tags"

        activitiesDiffCtrl.diff = [
            ["architecto", "perspiciatis", "testafo"],
            ["architecto", "perspiciatis", "testafo", "fasto"]
        ]

        activitiesDiffCtrl.diffTags()
        expect(activitiesDiffCtrl.diffRemoveTags).to.be.equal('')
        expect(activitiesDiffCtrl.diffAddTags).to.be.equal('fasto')

    it "build card links when a relation is created", () ->
        activitiesDiffCtrl = controller "ActivitiesDiffCtrl"

        activitiesDiffCtrl.type = "card_relation"
        activitiesDiffCtrl.model = {project_extra_info: {slug: "project-slug"}}
        activitiesDiffCtrl.diff = [
            null,
            {
                relation_type: "blocks"
                source_type: "task"
                source_ref: 12
                target_type: "userstory"
                target_ref: 34
            }
        ]

        mocks.translate.instant
            .withArgs("ACTIVITY.RELATIONSHIP_blocks")
            .returns("__SOURCE_LINK__ blocks __TARGET_LINK__")

        activitiesDiffCtrl.diffTags()

        expect(activitiesDiffCtrl.relationMode).to.be.equal("created")
        expect(activitiesDiffCtrl.relationClass).to.be.equal("relation-blocks")
        expect(activitiesDiffCtrl.sourceUrl).to.be.equal("/project/project-slug/task/12")
        expect(activitiesDiffCtrl.targetUrl).to.be.equal("/project/project-slug/us/34")
        expect(sce.getTrustedHtml(activitiesDiffCtrl.relationHtml)).to.be.equal(
            "<a class='relation-link' href='/project/project-slug/task/12'>#12</a> blocks " +
            "<a class='relation-link' href='/project/project-slug/us/34'>#34</a>"
        )

    it "keep plain refs when the relation has no project slug", () ->
        activitiesDiffCtrl = controller "ActivitiesDiffCtrl"

        activitiesDiffCtrl.type = "card_relation"
        activitiesDiffCtrl.model = {}
        activitiesDiffCtrl.diff = [
            {
                relation_type: "blocks"
                source_type: "task"
                source_ref: 12
                target_type: "userstory"
                target_ref: 34
                action: "removed"
            },
            null
        ]

        mocks.translate.instant
            .withArgs("ACTIVITY.RELATIONSHIP_REMOVED")
            .returns("__SOURCE_LINK__ no longer __TARGET_LINK__")

        activitiesDiffCtrl.diffTags()

        expect(activitiesDiffCtrl.relationMode).to.be.equal("removed")
        expect(activitiesDiffCtrl.sourceUrl).to.be.null
        expect(activitiesDiffCtrl.targetUrl).to.be.null
        expect(sce.getTrustedHtml(activitiesDiffCtrl.relationHtml)).to.be.equal("#12 no longer #34")
