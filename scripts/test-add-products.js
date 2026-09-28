'use strict';

/**
 * Automates the creation of 500 test products to verify database scaling, 
 * frontend table performance, and barcode uniqueness.
 *
 * Run with: node scripts/test-add-products.js
 */

const { Pool } = require('pg');

// Load environment variables dynamically
try {
  require('fs').readFileSync('.env', 'utf8')
    .split('\n').filter((l) => l && !l.startsWith('#'))
    .forEach((l) => {
      const [k, ...r] = l.split('=');
      if (k && r.length && !process.env[k.trim()]) process.env[k.trim()] = r.join('=').trim();
    });
} catch {}

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Find an existing category to assign the test products to
    console.log('• Looking for an active product category...');
    const { rows: categories } = await client.query('SELECT id, name FROM product_categories LIMIT 1');
    
    if (categories.length === 0) {
        throw new Error("No product categories found! Please create at least one category in the Admin Dashboard first.");
    }
    
    const categoryId = categories[0].id;
    console.log(`  Found category: "${categories[0].name}"`);

    // 2. Generate and insert 500 products
    console.log('• Generating 500 test products (this will be fast)...');
    
    const timestamp = Date.now(); // Used to guarantee unique barcodes and names

    for (let i = 1; i <= 500; i++) {
        // Generate randomized but realistic mock data
        const name = `Test Product ${i} (Batch ${timestamp})`;
        const barcode = `BARCODE-${timestamp}-${i}`;
        const real_price = Math.floor(Math.random() * 2000) + 500;   // Cost: 500 to 2500 DZD
        const price = real_price + Math.floor(Math.random() * 1000); // Selling: Cost + (0 to 1000 DZD profit)
        const commission = 50; 
        const threshold = 5;

        await client.query(
            `INSERT INTO products (name, category_id, price, real_price, commission_amount, low_stock_threshold, barcode)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [name, categoryId, price, real_price, commission, threshold, barcode]
        );
        
        // Output progress to the terminal
        if (i % 100 === 0) {
            console.log(`  ✓ Inserted ${i} / 500...`);
        }
    }

    await client.query('COMMIT');
    console.log('\n✅ Success! 500 test products have been added to your database.');
    
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// Execute the script
run()
  .then(() => pool.end())
  .catch((err) => {
    console.error('\n❌ Script failed:', err.message);
    pool.end();
    process.exit(1);
  });