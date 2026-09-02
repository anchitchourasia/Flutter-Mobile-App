import 'app_config.dart';

class ApiConfig {
  static const String baseUrl = AppConfig.apiBaseUrl;
  static const String apiKey = AppConfig.apiKey;

  // Temporary dummy backend configuration for mobile IN / OUT Gate Log.
  static const String dummyGateLogBaseUrl = AppConfig.dummyGateLogBaseUrl;

  static const String dummyGateLogApiKey = AppConfig.dummyGateLogApiKey;

  static const String cvpsBaseUrl = AppConfig.cvpsBaseUrl;

  // static const String dummyGateLogBaseUrl = AppConfig.dummyGateLogBaseUrl;

  // AUTH
  static String authorityByEmp = '$baseUrl/api/authority';
  static String authorityUpdate = '$baseUrl/api/authority/update';
  static String employeeReport = '$baseUrl/api/reports/employee-department';

  // PASSES / SAVE
  static String passSave = '$baseUrl/api/passes/save';
  static String passUpdate = '$baseUrl/api/passes/update';
  static String passListV1 = '$baseUrl/api/passes/listV1';
  static String passList = '$baseUrl/api/passes/list';
  static String passHistory = '$baseUrl/api/history';
  static String passStatusUpdate = '$baseUrl/api/passes/status';

  // DOCUMENTS DOWNLOAD
  static String documentsDownload = '$baseUrl/api/passes/documents/download';

  // Dummy backend endpoint used only by approved CVPS request IN/OUT buttons.
  static String dummyCvpsGateLogs = '$dummyGateLogBaseUrl/api/gate-logs';

  // CVPS (existing)
  static String cvpsBase = '$cvpsBaseUrl/api/requests';
  static String cvpsCreateRequest = '$cvpsBaseUrl/api/requests/create';
  static String cvpsUpdateRequest = '$cvpsBaseUrl/api/requests/update';
  static String cvpsGetRequestById = '$cvpsBaseUrl/api/requests';
  static String cvpsGetAllRequests = '$cvpsBaseUrl/api/requests';
  static String cvpsDeleteRequest = '$cvpsBaseUrl/api/requests';
  static String cvpsBpRecords = '$cvpsBaseUrl/api/bp-records';

  // CVPS – new endpoints (mirroring web API_CONFIG)
  static String cvpsGetManpowerDocuments(String empNo) =>
      '$cvpsBaseUrl/api/manpower/documents/$empNo';

  static String cvpsDownloadManpowerDocument(String fileName) =>
      '$cvpsBaseUrl/api/manpower/documents/download/$fileName';

  static String cvpsDepartmentList = '$cvpsBaseUrl/api/dept';
}
