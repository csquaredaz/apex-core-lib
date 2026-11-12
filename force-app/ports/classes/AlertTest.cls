@IsTest
private class AlertTest {
  @IsTest
  static void constructor_validArguments_keepsValues() {
    Alert raised = new Alert(Alert.Severity.CRITICAL, 'Carrier down', '3 shipments stuck', 'ShipmentsService');

    Assert.areEqual(Alert.Severity.CRITICAL, raised.severity, 'Severity');
    Assert.areEqual('Carrier down', raised.title, 'Title');
    Assert.areEqual('3 shipments stuck', raised.detail, 'Detail');
    Assert.areEqual('ShipmentsService', raised.source, 'Source');
  }

  @IsTest
  static void constructor_missingTitle_throws() {
    try {
      new Alert(Alert.Severity.INFO, ' ', null, null);
      Assert.fail('Expected IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('title'), e.getMessage());
    }
  }

  @IsTest
  static void constructor_missingSeverity_throws() {
    try {
      new Alert(null, 'Carrier down', null, null);
      Assert.fail('Expected IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('severity'), e.getMessage());
    }
  }
}
