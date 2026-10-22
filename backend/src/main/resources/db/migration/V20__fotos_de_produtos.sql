-- Fotos de produtos usam a mesma tabela e o mesmo armazenamento das fotos do portfólio,
-- mas não aparecem na galeria "Nossos trabalhos".
ALTER TABLE portfolio_photo ADD COLUMN product_id BIGINT REFERENCES product (id) ON DELETE CASCADE;
CREATE INDEX ix_portfolio_photo_product ON portfolio_photo (product_id);
