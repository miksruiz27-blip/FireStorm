import { app } from './app.js';
import { loadClassifiers } from './classifiers.js';
import { loadModel } from './model.js';

process.on('unhandledRejection', (e) => console.error('unhandledRejection', e));
process.on('uncaughtException', (e) => console.error('uncaughtException', e));

await loadModel();
await loadClassifiers();
const port = Number(process.env.PORT) || 3000;
app.listen(port, () => console.log(`FireStorm API on :${port}`));
