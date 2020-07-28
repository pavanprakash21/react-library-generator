#!/usr/bin/env

# ask for package name and create a new folder and cd into it
echo 'Please enter the package name'
read package_name
if [[ -z $package_name ]]; then
  echo 'Please provide a package name. Exiting'
  exit 1
else
  mkdir $package_name && cd $package_name
fi

# ask for remote url
echo 'Please enter the git remote url'
read remote_url
if [[ -n "$remote_url" ]]; then
  git init
  git remote add origin $remote_url
else
  echo 'You did not provide a remote url. You can always set later using `git remote add`'
  git init
fi

# initialize yarn
yarn init -y

# initialize git and add .gitignore
touch .gitignore
echo 'node_modules' >>.gitignore
echo 'dist' >>.gitignore
echo 'coverage' >>.gitignore

git add .
git commit -m 'Initial commit'

# add prettier and its config
yarn add --dev prettier
touch prettier.config.js
touch .prettierignore

echo 'module.exports = {
  parser: "typescript",
  semi: true,
  trailingComma: "all",
  singleQuote: true,
  printWidth: 120,
  tabWidth: 2
};' >prettier.config.js

echo 'yarn.lock
dist
node_modules' >.prettierignore

git add .
git commit -m 'Setup prettier'

# setup dependecies
yarn global add npe

# add typescript and its config
yarn add --dev typescript
echo '{
  "compilerOptions": {
    "target": "es5",
    "module": "es2015",
    "declaration": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "jsx": "react",
    "importsNotUsedAsValues": "preserve",
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "esModuleInterop": true,
    "baseUrl": ".",
    "paths": {
      "src/*": ["src/*"],
      "stories/*": ["stories/*"]
    },
  },
  "include": ["src/**/*"],
  "exclude": [
    "node_modules",
    "dist"
  ]
}' >tsconfig.json

git add .
git commit -m 'Setup typescript'

# setup eslint
yarn add --dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint-plugin-react eslint-config-prettier eslint-plugin-prettier

echo 'module.exports = {
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: "module",
    ecmaFeatures: {
      jsx: true
    }
  },
  settings: {
    react: {
      version: "detect"
    }
  },
  extends: [
    "plugin:react/recommended",
    "plugin:@typescript-eslint/recommended",
    "prettier/@typescript-eslint",
    "plugin:prettier/recommended"
  ],
  rules: {}
};' >.eslintrc.js

npe scripts.lint "eslint '*/**/*.{js,ts,tsx}' --quiet --fix"

git add .
git commit -m 'Setup eslint'

# add husky and lint-staged
yarn add --dev husky lint-staged
echo 'module.exports = {
  "hooks": {
    "pre-commit": "lint-staged"
  }
}' >husky.config.js

echo 'module.exports = {
  "*.{js,ts,tsx}": [
    "eslint --fix"
  ]
}'>lint-staged.config.js

git add .
git commit -m 'Setup pre commit hooks'

# setup rollup
yarn add --dev rollup rollup-plugin-typescript2
echo "import typescript from 'rollup-plugin-typescript2';
import path from 'path';

import pkg from './package.json';

const input = 'src/index.ts';

const output = [
  {
    dir: path.dirname(pkg.main),
    format: 'cjs',
    sourcemap: true,
  },
  {
    dir: path.dirname(pkg.module),
    format: 'esm',
    sourcemap: true,
  },
];

const plugins = [
  typescript({
    typescript: require('typescript'),
  }),
];

const external = [...Object.keys(pkg.dependencies || {}), ...Object.keys(pkg.peerDependencies || {})];

const rollupConfig = {
  plugins,
  external,
  preserveModules: true,
  input,
  output,
};

export default rollupConfig;" >rollup.config.js

# modify main and module
npe main dist/cjs/index.js
npe module dist/esm/index.js
npe scripts.build:ts 'rollup -c'
npe scripts.build:clean 'rm -rf dist'
npe scripts.build 'yarn build:clean && yarn build:ts'

git add .
git commit -m 'Setup rollup'

# add react
yarn add --dev react @types/react
npe peerDependencies.react $(npe devDependencies.react)

# add a dummy component
mkdir -p src/components/Hello
echo 'import React from "react";

export const Hello: React.FC = () => {
  return (
    <div>
      <h1>Pavan says Hello! 🎉</h1>
      <div>sample component</div>
    </div>
  );
};' >src/components/Hello/Hello.tsx

echo 'export { Hello } from "./Hello";' >src/components/Hello/index.tsx

echo 'export { Hello } from "./components/Hello";' >src/index.ts

git add .
git commit -m 'Setup react'

# check if everything is working fine
npm run build

# setup jest
yarn add --dev jest ts-jest @types/jest
npe scripts.test 'jest'
touch jest.config.js
echo "module.exports = {
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
  },
  testRegex: '(/__tests__/.*|\\.(test|spec))\\.(ts|tsx|js)$',
  moduleFileExtensions: [
      'ts',
      'tsx',
      'js'
    ]
};" >jest.config.js

# setup react testing
yarn add --dev @testing-library/react react-dom
touch src/components/Hello/Hello.spec.tsx
echo 'import React from "react";
import { render, screen } from "@testing-library/react";

import { Hello } from "./Hello";

describe("<Hello />", () => {
  test("rendered text", () => {
    render(<Hello />);
    expect(screen.getByText("sample component")).toBeDefined();
  });
});' >src/components/Hello/Hello.spec.tsx

npm test

git add .
git commit -m 'Setup testing'

# setup storybook
npx -p @storybook/cli sb init --type react
rm -r stories
yarn add --dev @storybook/preset-typescript ts-loader react-docgen-typescript-loader
yarn add --dev @storybook/addon-knobs @storybook/addon-a11y @storybook/addon-viewport @storybook/addon-info
echo 'const path = require("path");

const rootDir = path.resolve(__dirname);

module.exports = {
  stories: ["../src/**/*.stories.tsx"],
  addons: [
    "@storybook/addon-a11y/register",
    "@storybook/addon-actions/register",
    "@storybook/addon-knobs/register",
    "@storybook/addon-links/register",
    "@storybook/addon-viewport/register"
    "@storybook/preset-typescript",
  ],
  webpackFinal: async config => {
    config.module.rules.push({
      test: /\.(ts|tsx)$/,
      use: [
        {
          loader: require.resolve("ts-loader")
        },
        {
          loader: require.resolve("react-docgen-typescript-loader"),
        },
      ]
    });
    config.resolve.extensions.push(".ts", ".tsx");
    config.resolve.alias = {
      src: path.resolve(rootDir, "../src")
    };
    return config;
  }
};' >.storybook/main.js

npe scripts.storybook 'start-storybook -p 6006'
npe scripts.build-storybook 'build-storybook'

echo "import * as React from 'react';
import { Hello } from './Hello';

export default {
  title: 'Components',
  parameters: {
    info: { inline: true },
  },
};

export const HelloStory = () => <Hello />;" >src/components/Hello/Hello.stories.tsx

git add .
git commit -m 'Setup storybook'

# cleanup
yarn global remove npe

yarn storybook
