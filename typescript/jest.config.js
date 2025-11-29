module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  // Ignore the compiled output to avoid running tests twice
  modulePathIgnorePatterns: ["<rootDir>/dist/"]
};