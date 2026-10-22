-- Recarga completa (idempotente): esvazia e reinsere a partir do bronze.
DELETE FROM {{database}}.silver_cadunico;
