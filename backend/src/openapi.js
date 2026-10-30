const json = schema => ({
  'application/json': {schema},
});

const body = schema => ({
  required: true,
  content: json(schema),
});

const response = (description, schema) => ({
  description,
  ...(schema ? {content: json(schema)} : {}),
});

const ref = name => ({$ref: `#/components/schemas/${name}`});
const id = {
  name: 'id',
  in: 'path',
  required: true,
  schema: {type: 'string', format: 'uuid'},
};

const secured = {
  security: [{bearerAuth: []}],
};

const jsonResponse = (description, schema) => response(description, ref(schema));
const errors = {
  '400': response('Dữ liệu không hợp lệ'),
  '401': response('Chưa đăng nhập hoặc thông tin xác thực không hợp lệ'),
  '403': response('Không đủ quyền'),
  '404': response('Không tìm thấy tài nguyên'),
};

export const openapi = {
  openapi: '3.0.3',
  info: {
    title: 'GK-LTDD API',
    version: '1.0.0',
    description:
      'Tài liệu API cho ứng dụng GK-LTDD. Các endpoint yêu cầu đăng nhập cần Bearer token; lấy token sau khi xác minh OTP.',
  },
  servers: [{url: '/', description: 'Máy chủ hiện tại'}],
  tags: [
    {name: 'System'},
    {name: 'Authentication'},
    {name: 'Account'},
    {name: 'Children'},
    {name: 'Devices'},
    {name: 'Agreements'},
    {name: 'Check-ins'},
    {name: 'Location'},
    {name: 'Administration'},
  ],
  paths: {
    '/health': {
      get: {
        tags: ['System'],
        summary: 'Kiểm tra tình trạng API và cơ sở dữ liệu',
        responses: {
          '200': jsonResponse('API đang hoạt động', 'Health'),
          '503': response('Cơ sở dữ liệu không khả dụng'),
        },
      },
    },
    '/auth/register': {
      post: {
        tags: ['Authentication'],
        summary: 'Đăng ký tài khoản và gửi mã xác minh email',
        requestBody: body(ref('RegisterRequest')),
        responses: {
          '201': jsonResponse('Đã gửi mã OTP', 'Challenge'),
          ...errors,
          '409': response('Email hoặc tên tài khoản đã được sử dụng'),
        },
      },
    },
    '/auth/login': {
      post: {
        tags: ['Authentication'],
        summary: 'Đăng nhập bằng mật khẩu và gửi mã OTP',
        requestBody: body(ref('PasswordLoginRequest')),
        responses: {
          '200': jsonResponse('Đã gửi mã OTP', 'Challenge'),
          ...errors,
        },
      },
    },
    '/auth/login/otp': {
      post: {
        tags: ['Authentication'],
        summary: 'Yêu cầu mã OTP đăng nhập bằng email hoặc tên tài khoản',
        requestBody: body(ref('OtpLoginRequest')),
        responses: {
          '200': jsonResponse('Đã gửi mã OTP', 'Challenge'),
          ...errors,
        },
      },
    },
    '/auth/otp': {
      post: {
        tags: ['Authentication'],
        summary: 'Xác minh OTP để hoàn tất đăng nhập hoặc đăng ký',
        requestBody: body(ref('VerifyOtpRequest')),
        responses: {
          '200': jsonResponse('Đã xác minh OTP', 'Session'),
          ...errors,
        },
      },
    },
    '/auth/google/start': {
      get: {
        tags: ['Authentication'],
        summary: 'Bắt đầu đăng nhập Google; trình duyệt sẽ được chuyển hướng',
        parameters: [{
          name: 'verifierHash',
          in: 'query',
          required: true,
          schema: {type: 'string', pattern: '^[a-f0-9]{64}$'},
        }],
        responses: {
          '302': response('Chuyển hướng đến Google'),
          '503': response('Google OAuth chưa được cấu hình'),
        },
      },
    },
    '/auth/google/callback': {
      get: {
        tags: ['Authentication'],
        summary: 'Callback OAuth của Google; thường không gọi thủ công',
        parameters: [
          {name: 'code', in: 'query', required: true, schema: {type: 'string'}},
          {name: 'state', in: 'query', required: true, schema: {type: 'string'}},
        ],
        responses: {
          '302': response('Chuyển hướng trở lại ứng dụng'),
          '401': response('OAuth state không hợp lệ'),
        },
      },
    },
    '/auth/google/exchange': {
      post: {
        tags: ['Authentication'],
        summary: 'Đổi mã OAuth một lần thành phiên đăng nhập',
        requestBody: body(ref('GoogleExchangeRequest')),
        responses: {
          '200': jsonResponse('Phiên đăng nhập hoặc yêu cầu xác minh OTP', 'Session'),
          ...errors,
        },
      },
    },
    '/me': {
      get: {
        ...secured,
        tags: ['Account'],
        summary: 'Lấy tài khoản hiện tại',
        responses: {
          '200': jsonResponse('Thông tin tài khoản', 'User'),
          ...errors,
        },
      },
      patch: {
        ...secured,
        tags: ['Account'],
        summary: 'Cập nhật tên hiển thị',
        requestBody: body(ref('UpdateNameRequest')),
        responses: {
          '200': jsonResponse('Tài khoản đã cập nhật', 'User'),
          ...errors,
        },
      },
    },
    '/me/password': {
      patch: {
        ...secured,
        tags: ['Account'],
        summary: 'Tạo hoặc cập nhật mật khẩu',
        requestBody: body(ref('UpdatePasswordRequest')),
        responses: {
          '200': jsonResponse('Mật khẩu đã cập nhật', 'Message'),
          ...errors,
        },
      },
    },
    '/children': {
      get: {
        ...secured,
        tags: ['Children'],
        summary: 'Lấy danh sách hồ sơ trẻ được liên kết với tài khoản',
        responses: {
          '200': {
            description: 'Danh sách hồ sơ trẻ',
            content: json({type: 'array', items: ref('Child')}),
          },
          ...errors,
        },
      },
      post: {
        ...secured,
        tags: ['Children'],
        summary: 'Tạo hồ sơ trẻ (phụ huynh)',
        requestBody: body(ref('ChildRequest')),
        responses: {
          '201': jsonResponse('Đã tạo hồ sơ trẻ', 'Child'),
          ...errors,
        },
      },
    },
    '/children/{id}': {
      parameters: [id],
      put: {
        ...secured,
        tags: ['Children'],
        summary: 'Cập nhật hồ sơ trẻ (phụ huynh sở hữu)',
        requestBody: body(ref('ChildRequest')),
        responses: {
          '200': jsonResponse('Đã cập nhật hồ sơ trẻ', 'Child'),
          ...errors,
        },
      },
      delete: {
        ...secured,
        tags: ['Children'],
        summary: 'Xóa hồ sơ trẻ (phụ huynh sở hữu)',
        responses: {'204': response('Đã xóa hồ sơ'), ...errors},
      },
    },
    '/children/{id}/link': {
      parameters: [id],
      post: {
        ...secured,
        tags: ['Children'],
        summary: 'Liên kết tài khoản trẻ đã xác minh vào hồ sơ',
        requestBody: body(ref('LinkChildRequest')),
        responses: {
          '200': jsonResponse('Đã liên kết tài khoản trẻ', 'Message'),
          ...errors,
        },
      },
    },
    '/children/{id}/devices': {
      parameters: [id],
      get: {
        ...secured,
        tags: ['Devices'],
        summary: 'Liệt kê thiết bị của hồ sơ trẻ',
        responses: {
          '200': {
            description: 'Danh sách thiết bị',
            content: json({type: 'array', items: ref('Device')}),
          },
          ...errors,
        },
      },
      post: {
        ...secured,
        tags: ['Devices'],
        summary: 'Thêm thiết bị vào hồ sơ trẻ (phụ huynh)',
        requestBody: body(ref('DeviceRequest')),
        responses: {
          '201': jsonResponse('Đã thêm thiết bị', 'Device'),
          ...errors,
        },
      },
    },
    '/devices/{id}': {
      parameters: [id],
      put: {
        ...secured,
        tags: ['Devices'],
        summary: 'Đổi tên thiết bị (phụ huynh)',
        requestBody: body(ref('DeviceRequest')),
        responses: {'200': jsonResponse('Thiết bị đã cập nhật', 'Device'), ...errors},
      },
      delete: {
        ...secured,
        tags: ['Devices'],
        summary: 'Xóa thiết bị (phụ huynh)',
        responses: {'204': response('Đã xóa thiết bị'), ...errors},
      },
    },
    '/children/{id}/agreements': {
      parameters: [id],
      get: {
        ...secured,
        tags: ['Agreements'],
        summary: 'Liệt kê thỏa thuận của hồ sơ trẻ',
        responses: {
          '200': {
            description: 'Danh sách thỏa thuận',
            content: json({type: 'array', items: ref('Agreement')}),
          },
          ...errors,
        },
      },
      post: {
        ...secured,
        tags: ['Agreements'],
        summary: 'Tạo thỏa thuận (phụ huynh hoặc trẻ được liên kết)',
        requestBody: body(ref('AgreementRequest')),
        responses: {
          '201': jsonResponse('Đã tạo thỏa thuận', 'Agreement'),
          ...errors,
        },
      },
    },
    '/agreements/{id}': {
      parameters: [id],
      patch: {
        ...secured,
        tags: ['Agreements'],
        summary: 'Duyệt hoặc từ chối thỏa thuận (phụ huynh)',
        requestBody: body(ref('AgreementStatusRequest')),
        responses: {
          '200': jsonResponse('Thỏa thuận đã cập nhật', 'Agreement'),
          ...errors,
        },
      },
      delete: {
        ...secured,
        tags: ['Agreements'],
        summary: 'Xóa thỏa thuận (phụ huynh)',
        responses: {'204': response('Đã xóa thỏa thuận'), ...errors},
      },
    },
    '/children/{id}/nfc': {
      parameters: [id],
      put: {
        ...secured,
        tags: ['Check-ins'],
        summary: 'Gắn thẻ NFC vào hồ sơ trẻ (phụ huynh)',
        requestBody: body(ref('NfcRequest')),
        responses: {'200': jsonResponse('Đã gắn thẻ NFC', 'Message'), ...errors},
      },
    },
    '/children/{id}/checkins': {
      parameters: [id],
      get: {
        ...secured,
        tags: ['Check-ins'],
        summary: 'Lấy tối đa 50 lượt check-in gần nhất',
        responses: {
          '200': {
            description: 'Danh sách lượt check-in',
            content: json({type: 'array', items: ref('Checkin')}),
          },
          ...errors,
        },
      },
      post: {
        ...secured,
        tags: ['Check-ins'],
        summary: 'Ghi nhận check-in bằng thẻ NFC đã gắn',
        requestBody: body(ref('NfcRequest')),
        responses: {
          '201': jsonResponse('Đã ghi nhận check-in', 'Checkin'),
          ...errors,
          '403': response('Thẻ NFC không khớp'),
        },
      },
    },
    '/children/{id}/location': {
      parameters: [id],
      get: {
        ...secured,
        tags: ['Location'],
        summary: 'Lấy vị trí được chia sẻ gần nhất',
        responses: {
          '200': jsonResponse('Vị trí gần nhất hoặc null', 'Location'),
          ...errors,
        },
      },
      put: {
        ...secured,
        tags: ['Location'],
        summary: 'Chia sẻ/cập nhật vị trí (tài khoản trẻ đã liên kết)',
        requestBody: body(ref('LocationRequest')),
        responses: {'200': jsonResponse('Vị trí đã cập nhật', 'Location'), ...errors},
      },
      delete: {
        ...secured,
        tags: ['Location'],
        summary: 'Ngừng chia sẻ và xóa vị trí (tài khoản trẻ đã liên kết)',
        responses: {'204': response('Đã xóa vị trí'), ...errors},
      },
    },
    '/staff/dashboard': {
      get: {
        ...secured,
        tags: ['Administration'],
        summary: 'Lấy số liệu thống kê tổng hợp (staff/admin)',
        responses: {
          '200': jsonResponse('Số lượng tài khoản, hồ sơ và thiết bị', 'Dashboard'),
          ...errors,
        },
      },
    },
    '/admin/users': {
      get: {
        ...secured,
        tags: ['Administration'],
        summary: 'Liệt kê tối đa 200 tài khoản (admin)',
        responses: {
          '200': {
            description: 'Danh sách tài khoản',
            content: json({type: 'array', items: ref('User')}),
          },
          ...errors,
        },
      },
    },
    '/admin/users/{id}/role': {
      parameters: [id],
      patch: {
        ...secured,
        tags: ['Administration'],
        summary: 'Cấp quyền parent, child hoặc staff (admin)',
        requestBody: body(ref('RoleRequest')),
        responses: {
          '200': jsonResponse('Đã cập nhật quyền', 'User'),
          ...errors,
        },
      },
    },
  },
  components: {
    securitySchemes: {
      bearerAuth: {type: 'http', scheme: 'bearer', bearerFormat: 'JWT'},
    },
    schemas: {
      Health: {type: 'object', properties: {status: {type: 'string', example: 'ok'}}},
      Message: {type: 'object', properties: {message: {type: 'string'}}},
      RegisterRequest: {
        type: 'object',
        required: ['email', 'username', 'name', 'password'],
        properties: {
          email: {type: 'string', format: 'email'},
          username: {type: 'string', minLength: 3, maxLength: 32, pattern: '^[a-zA-Z0-9_]+$'},
          name: {type: 'string', minLength: 2, maxLength: 80},
          password: {type: 'string', minLength: 10, maxLength: 72},
        },
      },
      PasswordLoginRequest: {
        type: 'object',
        required: ['username', 'password'],
        properties: {
          username: {type: 'string', description: 'Tên tài khoản hoặc email'},
          password: {type: 'string'},
        },
      },
      OtpLoginRequest: {
        type: 'object',
        required: ['username'],
        properties: {username: {type: 'string', description: 'Tên tài khoản hoặc email'}},
      },
      VerifyOtpRequest: {
        type: 'object',
        required: ['challengeId', 'code'],
        properties: {
          challengeId: {type: 'string', format: 'uuid'},
          code: {type: 'string', pattern: '^\\d{6}$'},
        },
      },
      GoogleExchangeRequest: {
        type: 'object',
        required: ['code', 'verifier'],
        properties: {code: {type: 'string'}, verifier: {type: 'string', minLength: 32}},
      },
      Challenge: {
        type: 'object',
        properties: {
          challengeId: {type: 'string', format: 'uuid'},
          message: {type: 'string'},
          kind: {type: 'string'},
          requiresOtp: {type: 'boolean'},
        },
      },
      Session: {
        type: 'object',
        description: 'Google exchange có thể yêu cầu OTP; khi đăng nhập hoàn tất sẽ trả token và user.',
        properties: {
          token: {type: 'string'},
          user: ref('User'),
          challengeId: {type: 'string', format: 'uuid'},
          requiresOtp: {type: 'boolean'},
        },
      },
      User: {
        type: 'object',
        properties: {
          id: {type: 'string', format: 'uuid'},
          email: {type: 'string', format: 'email'},
          username: {type: 'string'},
          name: {type: 'string'},
          role: {type: 'string', enum: ['parent', 'child', 'staff', 'admin']},
          verified: {type: 'boolean'},
          hasPassword: {type: 'boolean'},
        },
      },
      UpdateNameRequest: {
        type: 'object',
        required: ['name'],
        properties: {name: {type: 'string', minLength: 2, maxLength: 80}},
      },
      UpdatePasswordRequest: {
        type: 'object',
        required: ['newPassword'],
        properties: {
          currentPassword: {type: 'string'},
          newPassword: {type: 'string', minLength: 10, maxLength: 72},
        },
      },
      ChildRequest: {
        type: 'object',
        required: ['name', 'age', 'daily_limit'],
        properties: {
          name: {type: 'string', minLength: 1, maxLength: 80},
          age: {type: 'integer', minimum: 1, maximum: 17},
          daily_limit: {type: 'integer', minimum: 15, maximum: 1440},
        },
      },
      Child: {
        allOf: [
          ref('ChildRequest'),
          {type: 'object', properties: {id: {type: 'string', format: 'uuid'}}},
        ],
      },
      LinkChildRequest: {
        type: 'object',
        required: ['email'],
        properties: {email: {type: 'string', format: 'email'}},
      },
      DeviceRequest: {
        type: 'object',
        required: ['name'],
        properties: {name: {type: 'string', minLength: 1, maxLength: 80}},
      },
      Device: {
        allOf: [
          ref('DeviceRequest'),
          {type: 'object', properties: {id: {type: 'string', format: 'uuid'}, child_id: {type: 'string', format: 'uuid'}}},
        ],
      },
      AgreementRequest: {
        type: 'object',
        required: ['title', 'reward'],
        properties: {
          title: {type: 'string', minLength: 3, maxLength: 200},
          reward: {type: 'integer', minimum: 1, maximum: 120},
        },
      },
      AgreementStatusRequest: {
        type: 'object',
        required: ['status'],
        properties: {status: {type: 'string', enum: ['approved', 'rejected']}},
      },
      Agreement: {
        allOf: [
          ref('AgreementRequest'),
          {type: 'object', properties: {id: {type: 'string', format: 'uuid'}, status: {type: 'string'}}},
        ],
      },
      NfcRequest: {
        type: 'object',
        required: ['tagHash'],
        properties: {tagHash: {type: 'string', pattern: '^[a-f0-9]{64}$'}},
      },
      Checkin: {
        type: 'object',
        properties: {
          id: {type: 'string', format: 'uuid'},
          child_id: {type: 'string', format: 'uuid'},
          created_at: {type: 'string', format: 'date-time'},
        },
      },
      LocationRequest: {
        type: 'object',
        required: ['latitude', 'longitude', 'accuracy'],
        properties: {
          latitude: {type: 'number', minimum: -90, maximum: 90},
          longitude: {type: 'number', minimum: -180, maximum: 180},
          accuracy: {type: 'number', minimum: 0, maximum: 100000},
        },
      },
      Location: {
        allOf: [
          ref('LocationRequest'),
          {type: 'object', properties: {child_id: {type: 'string', format: 'uuid'}, updated_at: {type: 'string', format: 'date-time'}}},
        ],
      },
      Dashboard: {
        type: 'object',
        properties: {
          users: {type: 'integer'},
          children: {type: 'integer'},
          devices: {type: 'integer'},
        },
      },
      RoleRequest: {
        type: 'object',
        required: ['role'],
        properties: {role: {type: 'string', enum: ['parent', 'child', 'staff']}},
      },
    },
  },
};
