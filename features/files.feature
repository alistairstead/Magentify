Feature: Files
  In order to test the app with production medias
  As a developer
  I want to pull (and push) medias assets from production server to my local machine

  Scenario: User runs $ mages:files:pull
    Given an app
    When I execute deploy
    Then Magento create some assets in media
    And I create some assets locally
    And I execute files:pull
    Then the local media directory should be synced

  Scenario: User runs $ mages:files:push
    Given an app
    When I execute deploy
    Then I create some assets locally
    And Magento create some assets in media
    And I execute files:push
    Then the remote media directory should be synced
