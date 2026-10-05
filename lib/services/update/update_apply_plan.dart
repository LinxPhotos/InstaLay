/// Result of staging + handing off to an external apply stub.
class UpdateApplyPlan {
  const UpdateApplyPlan({
    required this.stagingDir,
    required this.artifactPath,
    required this.stubPath,
    required this.message,
  });

  final String stagingDir;
  final String artifactPath;
  final String stubPath;
  final String message;
}
