# https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/about-code-owners
# GitHub will add CODEOWNERS as reviewers at the start of a pull request

*                                              @mbta/dotcom

# CMS-related code
/apps/cms/                                     @mbta/dotcom @amaisano
site/content_rewriter.ex                       @mbta/dotcom @amaisano
site/content_rewriters/                        @mbta/dotcom @amaisano
site_web/controllers/cms_controller.ex         @mbta/dotcom @amaisano
site_web/views/cms_view.ex                     @mbta/dotcom @amaisano
site_web/views/page_content_view.ex            @mbta/dotcom @amaisano
site_web/views/paragraph_view.ex               @mbta/dotcom @amaisano
site_web/views/partial_view.ex                 @mbta/dotcom @amaisano
site_web/views/teaser_view.ex                  @mbta/dotcom @amaisano
site_web/views/helpers/cms_helpers.ex          @mbta/dotcom @amaisano
site_web/views/helpers/cms_router_helpers.ex   @mbta/dotcom @amaisano
site_web/templates/cms/                        @mbta/dotcom @amaisano