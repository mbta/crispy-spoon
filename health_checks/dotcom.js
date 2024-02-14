const axios = require('axios');

const options = {
  baseURL: `https://${process.env.HOST}`,
  headers: {
    'User-Agent': 'Node',
  },
  method: 'get',
  timeout: 1000,
  url: '/_health',
}

exports.check = async _ => {
  try {
    const res = await axios.request(options);
    return res.status === 200;
  } catch (e) {
    return false;
  }
}
